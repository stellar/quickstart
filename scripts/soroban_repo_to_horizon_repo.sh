#!/usr/bin/env bash

# soroban_repo_to_horizon_repo.sh - given a soroban branch to horizon branch
#
# Syntax:   soroban_repo_to_horizon_repo.sh <soroban_branch_name>
#
# Examples: soroban_repo_to_horizon_repo.sh main

set -e
set -o pipefail

if [ "$#" -ne 1 ]; then
    echo "Syntax: ${0} <soroban_branch_name>"
    exit 1
fi

GO_MONOREPO=github.com/stellar/go
SOROBAN_BRANCH=$1
SOROBAN_REPO_GOMOD=https://raw.githubusercontent.com/stellar/soroban-rpc/${SOROBAN_BRANCH}/go.mod

# find the short commit from the soroban-rpc repository.
SHORT_COMMIT=$(curl -s ${SOROBAN_REPO_GOMOD} -o - | grep "${GO_MONOREPO} " | cut -d- -f3)

# find the long commit from the actual go repository using the short commit.
TEMPDIR=$(mktemp -d)
git clone -q https://${GO_MONOREPO}.git ${TEMPDIR}
CURRENT_DIR=$(pwd)
cd ${TEMPDIR}
git rev-parse ${SHORT_COMMIT}
rm -rf ${TEMPDIR}
cd ${CURRENT_DIR}
