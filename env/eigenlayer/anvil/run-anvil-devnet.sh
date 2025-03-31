#!/bin/bash

rm /cartesi-lambada-coprocessor/env/eigenlayer/anvil/devnet-operators-ready.flag
rm -rf /cartesi-lambada-coprocessor/contracts/out
rm -rf /cartesi-lambada-coprocessor/contracts/cache
rm -rf /cartesi-lambada-coprocessor/contracts/broadcast

# Spawn anvil
anvil --load-state /root/.anvil/state.json --host 0.0.0.0 --block-time 12 &
sleep 2

# This is needed for anvil to accumulate fee history, othewise provider
# from eigensdk-rs, used by setup-operator, will fail...
cast rpc anvil_mine 200 --rpc-url http://localhost:8545 > /dev/null
sleep 15

touch /cartesi-lambada-coprocessor/env/eigenlayer/anvil/devnet-operators-ready.flag

tail -f /dev/null