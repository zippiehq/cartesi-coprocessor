use clap::Parser;
#[derive(Parser, Clone, Debug)]
pub struct Options {
    #[clap(long, env = "OPERATOR_PRIVATE_KEY")]
    pub operator_private_key: String,

    #[clap(long, env = "OPERATOR_BLS_KEY")]
    pub operator_bls_key: String,

    #[clap(long, env = "HTTP_ENDPOINT")]
    pub http_endpoint: String,

    #[clap(long, env = "STRATEGY_DEPOSIT_ADDRESS")]
    pub strategy_deposit_address: String,

    #[clap(long, env = "STRATEGY_DEPOSIT_AMOUNT")]
    pub strategy_deposit_amount: u64,
   
    #[clap(long, env = "CHAIN_WRITER_READER_ADDRESSES")]
    pub chain_writer_reader_addresses: String,
    
    #[clap(long, env = "AVS_REGISTRY_WRITER_ADDRESSES")]
    pub avs_registry_writer_addresses: String,

    #[clap(long, env = "SOCKET")]
    pub socket: String
}
