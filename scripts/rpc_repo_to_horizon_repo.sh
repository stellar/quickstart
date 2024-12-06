#!/usr/bin/env bash

# rpc_repo_to_horizon_repo.sh - given an rpc branch to horizon branch
#
# Syntax:   rpc_repo_to_horizon_repo.sh <rpc_branch_name>
#
# Examples: rpc_repo_to_horizon_repo.sh main

set -e
set -o pipefail

if [ "$#" -ne 1 ]; then
    echo "Syntax: ${0} <rpc_branch_name>"
    exit 1
fi

GO_MONOREPO=github.com/stellar/go
RPC_BRANCH=$1
RPC_REPO_GOMOD=https://raw.githubusercontent.com/stellar/stellar-rpc/${RPC_BRANCH}/go.mod

# find the short commit from the stellar-rpc repository.
SHORT_COMMIT=$(curl -s ${RPC_REPO_GOMOD} -o - | grep "${GO_MONOREPO} " | cut -d- -f3)

# find the long commit from the actual go repository using the short commit.
TEMPDIR=$(mktemp -d)
git clone -q https://${GO_MONOREPO}.git ${TEMPDIR}
CURRENT_DIR=$(pwd)
cd ${TEMPDIR}
git rev-parse ${SHORT_COMMIT}
rm -rf ${TEMPDIR}
cd ${CURRENT_DIR}
