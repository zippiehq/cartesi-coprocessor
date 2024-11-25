use clap::Parser;
#[derive(Parser, Clone, Debug)]
pub struct Options {
    #[clap(long, env = "OPERATOR_PRIVATE_KEY")]
    pub operator_private_key: String,

    #[clap(long, env = "OPERATOR_BLS_KEY")]
    pub operator_bls_key: String,

    #[clap(long, env = "HTTP_ENDPOINT")]
    pub http_endpoint: String,
}
