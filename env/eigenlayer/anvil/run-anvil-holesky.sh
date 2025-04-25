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

cast send \
    --rpc-url http://0.0.0.0:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --value 900ether 0xEc1dc4D2a9459758DCe2bb13096F303a8FAF4c92

forge script \
    script/HoleskyForkCoprocessorDeployer.s.sol:HoleskyForkCoprocessorDeployer \
    --evm-version cancun \
    --rpc-url http://0.0.0.0:8545 \
    --private-key 0xa38181ab9321e4bfdfe8dae9f99b05529483bdf0254bd5bcbcc51232f26b8c36 \
    --broadcast \
    --ffi \
    -v

touch /holesky-fork-operators-ready.flag

tail -f /dev/null
