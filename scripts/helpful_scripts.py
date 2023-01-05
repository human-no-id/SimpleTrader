from brownie import accounts, config, network, interface, SimpleArbTrader
from web3 import Web3

FORKED_LOCAL_ENVIRONMENT = ["bsc-mainnet-fork", "bsc-main-fork", "mainnet-fork"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local"]


# function to get wallet address whether it's from a local environment or a forked environment
def get_account():
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENT
    ):
        return accounts[0]
    else:
        return accounts.add(config["wallets"]["from_key"])


# function to get the balance of the base token
def wrapped_token_balance(address, blockchain):
    # get the wrapped base token contract
    if blockchain == "ethereum":
        wrapped = interface.IWeth(
            config["networks"][network.show_active()]["weth_token"]
        )
    elif blockchain == "binance":
        wrapped = interface.IWbnb(
            config["networks"][network.show_active()]["wbnb_token"]
        )
    # get the balance of the wrapped base token in wei and ether
    wrapped_balance_wei = wrapped.balanceOf(address)
    wrapped_balance = Web3.fromWei(wrapped_balance_wei, "ether")
    return wrapped_balance


# function to get the base token balance in ether
def check_account_eth_balance(address):
    contract_balance = Web3.fromWei(address.balance(), "ether")
    return contract_balance


# get wrapped token, i.e. swap base for wrapped base token
def get_wrapped(value_wei, blockchain):
    account = get_account()
    if blockchain == "ethereum":
        wrapped = interface.IWeth(
            config["networks"][network.show_active()]["weth_token"]
        )
    elif blockchain == "binance":
        wrapped = interface.IWbnb(
            config["networks"][network.show_active()]["wbnb_token"]
        )

    tx = wrapped.deposit({"from": account, "value": value_wei})
    tx.wait(1)


# get balances
def show_balance(account, contract, blockchain):
    # get account balances
    ac_balance = [
        check_account_eth_balance(account),
        wrapped_token_balance(account, blockchain),
    ]
    # get contract balances
    con_balance = [
        check_account_eth_balance(contract),
        wrapped_token_balance(contract, blockchain),
    ]
    print("")
    print(
        f"Account Base Token balance is {ac_balance[0]} and Wrapped Base Token balance is {ac_balance[1]}"
    )
    print(
        f"Contract Base Token balance is {con_balance[0]} and Wrapped Base Token balance is {con_balance[1]}"
    )
    print("")


# fund the contract with the base token
def fund_with_base_token(contract, account, value, blockchain):
    value = Web3.toWei(value, "ether")
    tx = contract.fund({"from": account, "value": value})
    tx.wait(1)

    # check account and contract balances
    show_balance(account, contract, blockchain)


# fund the contract with the wrapped base token
def fund_with_wrapped_token(value, account, contract, blockchain):
    # convert value to wei
    value = Web3.toWei(value, "ether")

    # convert eth to weth
    get_wrapped(value, blockchain)

    # check account and contract balances
    show_balance(account, contract, blockchain)

    # choose between ether and bnb wrapped contracts
    if blockchain == "ethereum":
        wrapped = interface.IWeth(
            config["networks"][network.show_active()]["weth_token"]
        )
    elif blockchain == "binance":
        wrapped = interface.IWbnb(
            config["networks"][network.show_active()]["wbnb_token"]
        )

    # transfer the wrapped token to the contract
    contract_address = SimpleArbTrader[-1]
    wrapped_balance = wrapped.balanceOf(account)
    tx = wrapped.transfer(contract_address, wrapped_balance, {"from": account})
    tx.wait(1)

    # check account and contract balances
    show_balance(account, contract, blockchain)


# withdraw funds from the contract
def withdrawAllFunds(contract, blockchain, account):
    # # choose between ether and bnb wrapped contracts
    # if blockchain == "ethereum":
    #     wrapped = interface.IWeth(
    #         config["networks"][network.show_active()]["weth_token"]
    #     )
    # elif blockchain == "binance":
    #     wrapped = interface.IWbnb(
    #         config["networks"][network.show_active()]["wbnb_token"]
    #     )

    # withdraw contract balance
    tx = contract.withdrawWrappedBaseFunds({"from": account})
    tx.wait(1)

    # withdraw base tokens
    tx = contract.withdrawBaseFunds({"from": account})
    tx.wait(1)

    # check account and contract balances
    show_balance(account, contract, blockchain)


# function to execute the swap function of the smart contract
def executeSwap(
    blockchain,
    exchange,
    contract,
    value,
    swap_path_address,
    slippage,
    account,
):
    # get router addresses for primary and secondary dexes
    router_address0 = config["blockchain"][blockchain][exchange[0]]["router"]
    router_address1 = config["blockchain"][blockchain][exchange[1]]["router"]

    # convert the value to be swapped to wei
    value = Web3.toWei(value, "ether")

    # get contract objects for the router addresses
    r0 = interface.IRouter(router_address0)
    r1 = interface.IRouter(router_address1)

    # get swap results
    out1 = r0.getAmountsOut(value, swap_path_address[0])
    out2 = r1.getAmountsOut(out1[1], swap_path_address[1])
    print(f"{value} gives {out1[1]} and {out1[1]} gives {out2[1]}")

    out1 = r1.getAmountsOut(value, swap_path_address[0])
    out2 = r0.getAmountsOut(out1[1], swap_path_address[1])
    print(f"{value} gives {out1[1]} and {out1[1]} gives {out2[1]}")

    # send transaction using the multiswap function of the contract
    percentage = 100 - slippage
    tx = contract.multiSwap(
        router_address0,
        router_address1,
        swap_path_address[0][1],
        swap_path_address[1][0],
        percentage,
        0,
        {"from": account, "value": value},
    )
    tx.wait(1)

    # check account and contract balances
    show_balance(account, contract, blockchain)

    # get other token object
    swapped_token = interface.IERC20(swap_path_address[0][1])
    # get the contract balance of the other token in wei and ether
    swapped_token_wei = swapped_token.balanceOf(contract)
    swapped_token_balance = Web3.fromWei(swapped_token_wei, "ether")
    print(f"Contract Swapped Token balance is {swapped_token_balance}")
