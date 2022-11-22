SOROBAN_REPO_BRANCH=$1

#!/usr/bin/env bash

# soroban_repo_to_horizon_repo.sh - given a soroban branch to horizon branch
#
# Syntax:   soroban_repo_to_horizon_repo.sh <soroban_branch_name>
#
# Examples: soroban_repo_to_horizon_repo.sh main

set -e
if [ "$#" -ne 1 ]; then
    echo "Syntax: soroban_repo_to_horizon_repo.sh <soroban_branch_name>"
    exit 1
fi

SOROBAN_BRANCH=$1
SOROBAN_REPO_GOMOD=https://raw.githubusercontent.com/stellar/soroban-tools/${SOROBAN_BRANCH}/go.mod
curl -s ${SOROBAN_REPO_GOMOD} -o soroban.go.mod
cat soroban.go.mod | grep "github.com/stellar/go " | cut -d \- -f 3
rm -f soroban.go.mod
