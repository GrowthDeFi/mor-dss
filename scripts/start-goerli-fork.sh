#!/bin/bash

source .env

CHAIN_ID=5
GAS_LIMIT=30000000
FORK_URL='wss://goerli.infura.io/ws/v3/'$INFURA_PROJECT_ID

BALANCE=100000000000000000000000

npx ganache-cli \
	--allowUnlimitedContractSize \
	-q \
	-h 0.0.0.0 \
	-i $CHAIN_ID \
	--chainId $CHAIN_ID \
	-l $GAS_LIMIT \
	-f $FORK_URL \
	--account $PRIVATE_KEY,$BALANCE