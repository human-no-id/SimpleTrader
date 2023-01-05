# import the contract and some useful functions
from brownie import SimpleArbTrader
from scripts.helpful_scripts import get_account
from scripts.test_smart_contract import test_smart_contract_functions


# function to deploy smart contract
def deploy_contract():
    ACCOUNT = get_account()
    simple_arb_trader = SimpleArbTrader.deploy({"from": ACCOUNT})
    print(f"Contract deployed to {simple_arb_trader.address}")


# deploy contract and test out smart contract
def main():
    deploy_contract()
    test_smart_contract_functions()
