use alloy_primitives::{Address, Bytes, FixedBytes, U256};
use alloy_signer_local::PrivateKeySigner;
use clap::Parser;
use setup_operator::Options;
use eigen_client_avsregistry::writer::AvsRegistryChainWriter;
use eigen_client_elcontracts::{
    reader::ELChainReader,
    writer::{ELChainWriter, Operator},
};
use eigen_crypto_bls::BlsKeyPair;
use eigen_logging::get_test_logger;
use eigen_testing_utils::{
    anvil_constants::{
        get_avs_directory_address, get_delegation_manager_address,
        get_operator_state_retriever_address, get_registry_coordinator_address,
        get_rewards_coordinator_address, get_strategy_manager_address,
    },
    transaction::wait_transaction,
};
use std::{
    str::FromStr,
    time::{SystemTime, UNIX_EPOCH},
};
#[tokio::main]
async fn main() {
    let opt = Options::parse();
    let signer = PrivateKeySigner::from_str(&opt.operator_private_key).unwrap();
    let delegation_manager_address =
        get_delegation_manager_address(opt.http_endpoint.to_owned()).await;
    let avs_directory_address = get_avs_directory_address(opt.http_endpoint.to_owned()).await;
    let strategy_manager_address = get_strategy_manager_address(opt.http_endpoint.to_owned()).await;
    let rewards_coordinator_address =
        get_rewards_coordinator_address(opt.http_endpoint.to_owned()).await;
    let el_chain_reader = ELChainReader::new(
        get_test_logger(),
        Address::ZERO,
        delegation_manager_address,
        avs_directory_address,
        opt.http_endpoint.to_owned(),
    );

    let el_chain_writer = ELChainWriter::new(
        delegation_manager_address,
        strategy_manager_address,
        rewards_coordinator_address,
        el_chain_reader,
        opt.http_endpoint.to_string(),
        opt.operator_private_key.to_string(),
    );

    let operator_details = Operator {
        address: signer.address(),
        earnings_receiver_address: signer.address(),
        delegation_approver_address: signer.address(),
        staker_opt_out_window_blocks: 3,
        metadata_url: Some("eigensdk-rs".to_string()),
    };

    let _ = el_chain_writer
        .register_as_operator(operator_details)
        .await
        .unwrap();

        let deposit_into_strategy = el_chain_writer
        .deposit_erc20_into_strategy(Address::parse_checksummed(opt.strategy_deposit_address, None).unwrap(), U256::from(opt.strategy_deposit_amount))
        .await
        .unwrap();

    let _ = wait_transaction(&opt.http_endpoint, deposit_into_strategy).await.unwrap();

    let avs_registry_writer = AvsRegistryChainWriter::build_avs_registry_chain_writer(
        get_test_logger(),
        opt.http_endpoint.to_string(),
        opt.operator_private_key.to_string(),
        get_registry_coordinator_address(opt.http_endpoint.to_owned()).await,
        get_operator_state_retriever_address(opt.http_endpoint.to_owned()).await,
    )
    .await
    .unwrap();

    let bls_key_pair = BlsKeyPair::new(opt.operator_bls_key.to_string()).unwrap();
    let salt: FixedBytes<32> = FixedBytes::from([0x02; 32]);
    let now = SystemTime::now();
    let seconds_since_epoch = now.duration_since(UNIX_EPOCH).unwrap().as_secs();
    let expiry = U256::from(seconds_since_epoch) + U256::from(10000);
    let quorum_numbers = Bytes::from_str("0x00").unwrap();
    let socket = "socket";

    let tx_hash = avs_registry_writer
        .register_operator_in_quorum_with_avs_registry_coordinator(
            bls_key_pair,
            salt,
            expiry,
            quorum_numbers,
            socket.to_string(),
        )
        .await
        .unwrap();
    wait_transaction(&opt.http_endpoint, tx_hash).await.unwrap();
}
