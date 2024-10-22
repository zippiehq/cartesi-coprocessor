# Cartesi-Coprocessor-SDK(Python-tutorial)

## Prerequisites
- **NoNodo**
- **Cartesi Machine**
- **Node version 18 or higher**

### Install Tools
1. **NoNodo**  
Install globally via npm
```bash
npm i -g nonodo
```
2. **Cartesi Machine**  
Download the [Cartesi Machine image](https://github.com/edubart/cartesi-machine-everywhere/releases/tag/v0.18.1-rc6) for your OS and add the `bin/` folder to your PATH:
```bash
export PATH="/path/to/cartesi-machine/bin:$PATH"
```
3. **web3.storage setup**
```
npm install -g @web3-storage/w3cli
```
4. **Install foundry**
```
curl -L https://foundry.paradigm.xyz | bash
```
- follow instructions from the output before installing foundry by running the command
```
foundryup
```
## Development
1. **Start NoNodo**:
```bash
nonodo
```
2. **Create a python Cartesi dApp**:
```bash
cartesi create sample-dapp --template=python
cd sample-dapp
cartesi build
```
3. **Run the Cartesi Machine**:
```bash
cartesi-machine --network --flash-drive=label:root,filename:.cartesi/image.ext2 \
--volume=.:/mnt --env=ROLLUP_HTTP_SERVER_URL=http://10.0.2.2:5004 --workdir=/mnt -- python dapp.py
```
## Using the CARize utility container
clone and build the docker image
```bash
git clone https://github.com/nyakiomaina/carize.git
cd carize
docker build -t carize:latest .
```
**Run the utility container**
```
docker run --rm \
    -v $(pwd)/.cartesi/image:/data \
    -v $(pwd):/output \
    carize:latest /carize.sh
```
## Uploading CAR files to W3.Storage
### Login to web3.storage
```
w3 login yourEmail@example.com
```
### Create a Storage Space
```
w3 space create preferredSpaceName
```
### Upload Files to Web3.Storage
```
w3 up --car /output/output.car
```

## Ensure coprocessor has your program
**Using the ```/ensure``` api**
```
cucurl -X POST "http://lambada.tspre.org/ensure/$CID/$MACHINE_HASH/$SIZE"
```
Replace cid, machine_hash, and size with your actual value which is the output from the carize. Check output.car.json file

## Foundry set up to interact with the coprocessor
### confirm foundry installation
```
forge --version
```
If you haven't installed Foundry yet, refer back to the installation step above
### clone the Foundry Template Repository
template repository contains the ICoprocessor.sol interface and sample contract:
```
git clone https://github.com/nyakiomaina/cartesi-coprocessor-template.git
cd cartesi-coprocessor-template
```
### get dependencies
```
forge install
```
### build contract
```
forge build
```

