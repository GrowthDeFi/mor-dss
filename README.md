# mor-dss

[![Truffle CI Actions Status](https://github.com/GrowthDeFi/mor-dss/workflows/Truffle%20CI/badge.svg)](https://github.com/GrowthDeFi/mor-dss/actions)

## Repository Organization

* [/contracts/](contracts). This folder is where the smart contract source code
  resides.
* [/migrations/](migrations). This folder hosts the relevant set of Truffle
  migration scripts used to publish the smart contracts to the blockchain.
* [/scripts/](scripts). This folder contains scripts to run local forks.
* [/test/](test). This folder contains relevant unit tests for Truffle written
  in Solidity.

## Building, Deploying and Testing

Configuring the repository:

    $ npm i

Compiling the smart contracts:

    $ npm run build

Running the unit tests:

    $ ./scripts/start-bscmain-fork.sh & npm run test

_(Standard installation of Node 14.15.4 on Ubuntu 20.04)_
