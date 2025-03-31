#!/bin/bash

RPC_URL=http://localhost:8545
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# cd to the directory of this script so that this can be run from anywhere
parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)
# At this point we are in tests/anvil
cd "$parent_path"

set -a
source ./utils.sh
set +a

cleanup() {
    echo "Executing cleanup function..."
    set +e
    docker rm -f anvil
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "Script exited due to set -e on line $1 with command '$2'. Exit status: $exit_status"
    fi
}
trap 'cleanup $LINENO "$BASH_COMMAND"' EXIT

# start an empty anvil chain in the background and dump its state to a json file upon exit
start_anvil_docker "" $parent_path/env/eigenlayer/anvil/eigenlayer-deployed-anvil-state.json

cd ./contracts
cast rpc anvil_mine 2 --rpc-url $RPC_URL > /dev/null
forge script script/DevnetEigenlayerDeployer.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv