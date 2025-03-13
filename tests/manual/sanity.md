# sanity check

### Checkout to Testing Branch

### Check for Running Containers
```bash
docker ps
```

### Stop Existing Containers (if any)
```bash
docker compose -f docker-compose-devnet.yaml down
```

### Build Docker Images
```bash
docker compose -f docker-compose-devnet.yaml build
```

### Start Containers in Detached Mode
```bash
docker compose -f docker-compose-devnet.yaml up --wait -d
```

### Verify Container Images and Tags
```bash
docker ps
```

## usage

### new DApp
```bash
cartesi-coprocessor create --dapp-name <project_name> --template <language template>
```

```bash
cd <project_name>
```

### Publish DApp
```bash
cartesi-coprocessor publish --network <devnet, mainnet or testnet>
```

### Check Publication Status
```bash
cartesi-coprocessor publish-status --network <devnet, mainnet or testnet>
```

### View Address Book
```bash
cartesi-coprocessor address-book
```

### Deploy Contract
```bash
cartesi-coprocessor deploy --contract-name <contract name> --network <devnet, mainnet or testnet> --constructor-args <devnet-task-issuer-address> <machine-hash>
```

### Run Execution (using cast)
```bash
cast send --unlocked --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 <deployed-contract-address> "runExecution(bytes)" "0x1234"
```
