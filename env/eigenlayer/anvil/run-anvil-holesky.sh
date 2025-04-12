#!/bin/bash
rm /holesky-fork-operators-ready.flag

rm /cartesi-lambada-coprocessor/contracts/script/output/holesky_fork_coprocessor_deployment.json

rm -rf /cartesi-lambada-coprocessor/contracts/out
rm -rf /cartesi-lambada-coprocessor/contracts/cache
rm -rf /cartesi-lambada-coprocessor/contracts/broadcast

ANVIL_FORK_URL=`cat /run/secrets/anvil_fork_url_holesky`
anvil --hardfork cancun --no-rate-limit --fork-url $ANVIL_FORK_URL --host 0.0.0.0 --block-time 1 -vvvvv &
sleep 15

cd /cartesi-lambada-coprocessor/contracts

forge script \
    script/HoleskyForkCoprocessorDeployer.s.sol:HoleskyForkCoprocessorDeployer \
    --evm-version cancun \
    --rpc-url http://0.0.0.0:8545 \
    --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d \
    --broadcast \
    --ffi \
    -v

touch /holesky-fork-operators-ready.flag

tail -f /dev/null
