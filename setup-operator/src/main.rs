use alloy_primitives::{Address, Bytes, FixedBytes, U256};
use alloy_signer_local::PrivateKeySigner;
use clap::Parser;
use eigen_client_avsregistry::writer::AvsRegistryChainWriter;
use eigen_client_elcontracts::{
    reader::ELChainReader,
    writer::{ELChainWriter, Operator},
};
use eigen_crypto_bls::BlsKeyPair;
use eigen_logging::get_test_logger;
use eigen_testing_utils::transaction::wait_transaction;
use eigen_utils::erc20::ERC20;
use eigen_utils::get_signer;
use eigen_utils::strategymanager::StrategyManager;
use setup_operator::Options;
use std::{
    fs::File,
    path::Path,
    str::FromStr,
    time::{SystemTime, UNIX_EPOCH},
};

#[tokio::main]
async fn main() {
    let opt = Options::parse();
    let signer = PrivateKeySigner::from_str(&opt.operator_private_key).unwrap();

    let deployment_parameters_devnet = File::open(Path::new(
        &opt.chain_writer_reader_addresses,
    ))
    .unwrap();

    let json: serde_json::Value = serde_json::from_reader(deployment_parameters_devnet).unwrap();

    let delegation_manager_address = Address::parse_checksummed(
        json.get("delegationManager").unwrap().as_str().unwrap(),
        None,
    )
    .unwrap();

    let avs_directory_address = Address::parse_checksummed(
        json.get("avsDirectory").unwrap().as_str().unwrap(),
        None,
    )
    .unwrap();

    let strategy_manager_address = Address::parse_checksummed(
        json.get("strategyManager").unwrap().as_str().unwrap(),
        None,
    )
    .unwrap();

    let rewards_coordinator_address = Address::parse_checksummed(
        json.get("avsDirectory").unwrap().as_str().unwrap(),
        None,
    )
    .unwrap();

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
        el_chain_reader.clone(),
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

    let tokens = el_chain_reader
        .get_strategy_and_underlying_erc20_token(
            Address::parse_checksummed(opt.strategy_deposit_address.clone(), None).unwrap(),
        )
        .await
        .unwrap();
    let (_, underlying_token_contract, underlying_token) = tokens;

    let provider = get_signer(
        &opt.operator_private_key.to_string(),
        &opt.http_endpoint.to_string(),
    );
    let contract_underlying_token = ERC20::new(underlying_token_contract, &provider);

    let contract_call = contract_underlying_token.approve(
        strategy_manager_address,
        U256::from(opt.strategy_deposit_amount),
    );
    let _ = contract_call.send().await.unwrap().watch().await.unwrap();
    let contract_strategy_manager = StrategyManager::new(strategy_manager_address, &provider);

    let deposit_contract_call = contract_strategy_manager.depositIntoStrategy(
        Address::parse_checksummed(opt.strategy_deposit_address, None).unwrap(),
        underlying_token,
        U256::from(opt.strategy_deposit_amount),
    );

    let tx: FixedBytes<32> = deposit_contract_call
        .send()
        .await
        .unwrap()
        .watch()
        .await
        .unwrap();

    wait_transaction(&opt.http_endpoint, tx).await.unwrap();

    let coprocessor_deployment_output_devnet = File::open(Path::new(
        &opt.avs_registry_writer_addresses,
    ))
    .unwrap();

    let json: serde_json::Value = serde_json::from_reader(coprocessor_deployment_output_devnet).unwrap();

    let registry_coordinator = Address::parse_checksummed(
        json.get("addresses").unwrap().get("registryCoordinator").unwrap().as_str().unwrap(),
        None,
    )
    .unwrap();

    let operator_state_retriever = Address::parse_checksummed(
        json.get("addresses").unwrap().get("operatorStateRetriever").unwrap().as_str().unwrap(),
        None,
    )
    .unwrap();
    let avs_registry_writer = AvsRegistryChainWriter::build_avs_registry_chain_writer(
        get_test_logger(),
        opt.http_endpoint.to_string(),
        opt.operator_private_key.to_string(),
        registry_coordinator,
        operator_state_retriever,
    )
    .await
    .unwrap();

    let bls_key_pair = BlsKeyPair::new(opt.operator_bls_key.to_string()).unwrap();
    let salt: FixedBytes<32> = FixedBytes::from([0x02; 32]);
    let now = SystemTime::now();
    let seconds_since_epoch = now.duration_since(UNIX_EPOCH).unwrap().as_secs();
    let expiry = U256::from(seconds_since_epoch) + U256::from(10000);
    let quorum_numbers = Bytes::from_str("0x00").unwrap();

    let tx_hash = avs_registry_writer
        .register_operator_in_quorum_with_avs_registry_coordinator(
            bls_key_pair,
            salt,
            expiry,
            quorum_numbers,
            opt.socket,
        )
        .await
        .unwrap();
    wait_transaction(&opt.http_endpoint, tx_hash).await.unwrap();
}
