#!/bin/bash

source .env

CHAIN_ID=137
GAS_LIMIT=281474976710655
FORK_URL='https://rpc-mainnet.maticvigil.com/'

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
