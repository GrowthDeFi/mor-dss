#!/bin/bash

source .env

CHAIN_ID=250
GAS_LIMIT=8000000
FORK_URL='https://rpc.ftm.tools/'

BALANCE=100000000000000000000000

npx ganache-cli \
	-q \
	-h 0.0.0.0 \
	-i 1 \
	--chainId $CHAIN_ID \
	-l $GAS_LIMIT \
	-f $FORK_URL \
	--account $PRIVATE_KEY,$BALANCE
