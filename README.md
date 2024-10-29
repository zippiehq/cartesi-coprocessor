# Cartesi Coprocessor SDK (Python Tutorial)

## Prerequisites
- nonodo
- Cartesi Machine
- Node.js version 18 or higher

## Install Tools
1. **Install nonodo**
Install nonodo globally via npm:
```
npm i -g nonodo
```
2. **Install cartesi machine**

Download the Cartesi Machine image for your OS from from [this link](https://github.com/edubart/cartesi-machine-everywhere/releases) and add the bin/ folder to your PATH:

```
export PATH="/path/to/cartesi-machine/bin:$PATH"
```
3. **Set up web3.storage**

Install the web3.storage CLI globally:

```
npm install -g @web3-storage/w3cli
```
4. **Install foundry**

Download and run the Foundry installer script:

```
curl -L https://foundry.paradigm.xyz | bash
```
After the installation, initialize Foundry:
```
foundryup
```
5. **Build the CARize utility container**

Clone the CARize repository and build the Docker image:

```
git clone https://github.com/nyakiomaina/carize.git
cd carize
docker build -t carize:latest .
```
## Development
1. **Start nonodo**
```
nonodo
```
2. **Create a python cartesi dApp**
```
cartesi create sample-dapp --template=python --branch "wip/coprocessor"
cd sample-dapp
```
3. **Build the Cartesi dApp**
```
cartesi build
```
4. **Run the cartesi machine**
```
cartesi-machine --network --flash-drive=label:root,filename:.cartesi/image.ext2 \
--volume=.:/mnt --env=ROLLUP_HTTP_SERVER_URL=http://10.0.2.2:5004 --workdir=/mnt -- python dapp.py
```
5. **Run the CARize Utility Container**

After building your dApp, run the CARize container to generate necessary files:

```
docker run --rm \
    -v $(pwd)/.cartesi/image:/data \
    -v $(pwd):/output \
    carize:latest /carize.sh
```
6. **Set environment variables**

Set the variables by reading the values from the output files generated after running the ```carize.sh``` script:
```
CID=$(cat output.cid)
SIZE=$(cat output.size)
MACHINE_HASH=$(xxd -p .cartesi/image/hash | tr -d '\n')
```

#### Uploading CAR Files to Web3.Storage
1. **Log In to web3.storage**
```
w3 login yourEmail@example.com
```
2. **Create a storage space**
```
w3 space create preferredSpaceName
```
3. **Upload files to Web3.Storage**
```
w3 up --car output.car
```
#### Ensure Coprocessor has your program

Use the ```/ensure``` API with the variables you've set:

```
curl -X POST "https://cartesi-coprocessor-solver.fly.dev/ensure/$CID/$MACHINE_HASH/$SIZE"
```
#### Monitor outputs

You can monitor the outputs using nonodo by accessing the GraphQL interface at:  http://localhost:8080/graphql

run ``cartesi send`` and send a generic input, in my case, sent a string 'hello'

Sample:
```
cartesi send
✔ Select send sub-command Send generic input to the application.
✔ Chain Foundry
✔ RPC URL http://127.0.0.1:8545
✔ Wallet Mnemonic
✔ Mnemonic test test test test test test test test test test test junk
✔ Account 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 9999.968655384479878868 ETH
✔ Application address 0xab7528bb862fB57E8A2BCd567a2e929a0Be56a5e
✔ Input String encoding
✔ Input (as string) hello
✔ Input sent: 0xa65e3f82179fac27ac9656f0ae82a4c5d0de5008c6977bbfb5ead18a01a20804
```
After sending the input, you can query both the outputs and the inputs given to them using the following GraphQL query:

```
query notices {
  notices {
    edges {
      node {
        index
        input {
          index
          payload
        }
        payload
      }
    }
  }
}
```
Execute query and the output should looks like this:

```
{
  "data": {
    "notices": {
      "edges": [
        {
          "node": {
            "index": 0,
            "input": {
              "index": 0,
              "payload": "0x68656c6c6f"
            },
            "payload": "0x68656c6c6f"
          }
        }
      ]
    }
  }
}
```

## Foundry setup to interact with the Coprocessor

1. **Confirm foundry installation**
```
forge --version
```
If Foundry isn't installed, refer back to the Install Foundry step.

2. **Clone the foundry template repository**

This template repository contains the ICoprocessor.sol interface and a sample contract:

```
git clone https://github.com/zippiehq/cartesi-coprocessor-contract-template.git
cd cartesi-coprocessor-contract-template
```
3. **Get dependencies**

```
forge install
```

4. **Build the contract**
```
forge build
```
5. **Deployment**

Replace placeholders with your actual RPC URL, private key, and Etherscan API key

```
COPROCESSOR_ADDRESS=0xB819BA4c5d2b64d07575ff4B30d3e0Eca219BFd5 MACHINE_HASH=0x<machine_hash_here> forge script script/Deploy.s.sol:DeployScript --rpc-url --private-key --etherscan-api-key --broadcast --verify
```
(run this to get the machine hash

```
 echo "Machine Hash: $MACHINE_HASH"
```
)
