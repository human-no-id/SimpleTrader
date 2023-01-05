# test out functions of the smart contract

from brownie import SimpleArbTrader
from scripts.helpful_scripts import (
    get_account,
    show_balance,
    fund_with_wrapped_token,
    withdrawAllFunds,
    executeSwap,
    fund_with_base_token,
)
from web3 import Web3


def test_smart_contract_functions():
    base_token = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
    other_token = "0x55d398326f99059fF775485246999027B3197955"
    # FACTORY = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
    # ROUTER = "0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8"

    exchange_path = [["biswap", "pancakeswap"], ["pancakeswap", "biswap"]]
    BLOCKCHAIN = "binance"
    VALUE = 1000
    SLIPPAGE = 1
    EXCHANGE = exchange_path[0]
    ACCOUNT = get_account()
    TRADER_CONTRACT = SimpleArbTrader[-1]

    # # to cover any gas fees during testing
    # fund_with_base_token(
    #     contract=TRADER_CONTRACT, account=ACCOUNT, value=VALUE, blockchain=BLOCKCHAIN
    # )

    # # test flashswap
    # VALUE_wei = Web3.toWei(VALUE, "ether")
    # TRADER_CONTRACT.flashSwap(
    #     base_token, other_token, 0, VALUE_wei, FACTORY, ROUTER, {"from": ACCOUNT}
    # )

    # # call function to fund the contract with wrapped eth
    # fund_with_wrapped_token(
    #     value=VALUE, account=ACCOUNT, contract=TRADER_CONTRACT, blockchain=BLOCKCHAIN
    # )

    print("Attempting Swap...")
    executeSwap(
        blockchain=BLOCKCHAIN,
        exchange=EXCHANGE,
        contract=TRADER_CONTRACT,
        value=VALUE,
        swap_path_address=[
            [
                base_token,
                other_token,
            ],
            [
                other_token,
                base_token,
            ],
        ],
        slippage=SLIPPAGE,
        account=ACCOUNT,
    )

    # # check account and contract balances
    # show_balance(account=ACCOUNT, contract=TRADER_CONTRACT, blockchain=BLOCKCHAIN)

    # # withdraw all funds from contracts
    # withdrawAllFunds(contract=TRADER_CONTRACT, blockchain=BLOCKCHAIN, account=ACCOUNT)
