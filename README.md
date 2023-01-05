# Deploy a Solidity smart contract using Brownie

This project includes:

1. a Solidity smart contract to execute an arbitrage trade in a single transaction;
2. functions to deploy a Solidity smart contract to Binance Smart Chain (or any other EVM based blockchain) using Brownie; and
3. functions written in Python to interact with the functions of a deployed Solidity smart contract.

The arbitrage trade smart contract ('1' above) was also extended to include flashswap functions.  
This smart contract was tested on Binance Smart Chain but it was not competitive enough to be successful.  
This is likely due to a combination of MEV, flashbots, and the simplicity of the trading strategy.  
More advanced techniques or alternative chains might have a higher chance of success.
