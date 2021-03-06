#!/bin/bash

source .env

CHAIN_ID=4
GAS_LIMIT=15000000
FORK_URL='wss://rinkeby.infura.io/ws/v3/'$INFURA_PROJECT_ID

BALANCE=100000000000000000000000

npx ganache-cli \
	-q \
	-h 0.0.0.0 \
	-i $CHAIN_ID \
	--chainId $CHAIN_ID \
	-l $GAS_LIMIT \
	-f $FORK_URL \
	--account $PRIVATE_KEY,$BALANCE
