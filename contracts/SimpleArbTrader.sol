// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "./UniswapV2Library.sol";
import "interfaces/IPair.sol";
import "interfaces/IERC20.sol";
import "interfaces/IRouter.sol";
import "interfaces/IFactory.sol";
import "interfaces/IWrappedV2.sol";
import "interfaces/IWrapped.sol";

// arbitrage smart contract

contract SimpleArbTrader {
    //address of wallet that deployed the contract
    address public owner;
    address public _wbaseCoin = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address[] flashDEX;

    IWrappedV2 wbaseCoin = IWrappedV2(_wbaseCoin);

    // the constructor is the first thing that happens when the contract is first instantiated
    // so this is the best time to allocate an owner of the contract - the person that deploys the contract is the owner
    constructor() {
        owner = msg.sender;
    }

    // fundable contract
    receive() external payable {}

    // restricted to only the owner of the smart contract
    modifier onlyOwner() {
        require(msg.sender == owner, "No Access");
        _;
    }

    // withdraw all base funds in the contract to the owner
    function withdrawBase() public onlyOwner {
        (bool sent, ) = payable(msg.sender).call{value: address(this).balance}(
            new bytes(0)
        );

        // if failed throw error on blockchain
        require(sent, "Failed to milk the contract!");
    }

    // function to withdraw ERC20 funds from contract to the owner
    function harvestERC20(address _tokenContract) public onlyOwner {
        // get the ERC20 contract
        IERC20 tokenContract = IERC20(_tokenContract);

        // get the amount of the token in the contract
        uint256 amount = tokenContract.balanceOf(address(this));

        // transfer the token from contract to owner
        bool sent = tokenContract.transfer(msg.sender, amount);

        // if failed throw error on blockchain
        require(sent, "Failed to harvest the contract!");
    }

    // see the balance of the base coin (eg ETH) in the contract
    function base_balance() public view returns (uint256) {
        return address(this).balance;
    }

    // get the contract balance of a particular ERC20 token
    function ERC20Balance(address ERC20_address) public view returns (uint256) {
        // get ERC20 contract
        IERC20 tokenContract = IERC20(ERC20_address);

        // get the amount of token recieved after swap available in the contract
        uint256 ERC20_balance = tokenContract.balanceOf(address(this));

        return ERC20_balance;
    }

    // function to execute a swap on a UNISWAP style dex for any valid ERC20 trading pair - can only be called by contract
    function dexSwap(
        address _routerAddress,
        uint256 _amountIn,
        address[] memory _path,
        uint256 _percentage
    ) private {
        // just to make sure the funds are actually available
        require(_amountIn > 0, "Insufficient funds in the contract");

        // get ERC20 token contract
        IERC20 tokenContract = IERC20(_path[0]);

        // approve the ERC20 token and amount that will be swapped via exchange router
        tokenContract.approve(_routerAddress, _amountIn);

        // get the router contract for exchange
        IRouter swapContract = IRouter(_routerAddress);

        // get a quote for the min amount out based on the amount in and the trade path in exchange0
        uint256[] memory _amountOutMin = swapContract.getAmountsOut(
            _amountIn,
            _path
        );

        uint256 getAmount = (_amountOutMin[1] / 100) * _percentage;

        // execute swap in exchange
        swapContract.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            getAmount,
            _path,
            address(this),
            block.timestamp
        );
    }

    // function to execute arbitrage opportunity - can only be called by owner
    // this function is designed to use the contract as a funnel for the funds from the owner
    // to wrap the token, execute the swap, unwrap and harvest the the balance
    // but only if the balance is greater than the input amount plus a tolerance
    function multiSwap(
        address _routerAddress0,
        address _routerAddress1,
        address _xch0_t1,
        address _xch1_t0,
        uint256 _percentage,
        uint256 _trap
    ) public payable onlyOwner {
        // automatically wrap incoming funds
        wbaseCoin.deposit{value: msg.value}();

        // amount to swap
        uint256 _amountIn0 = msg.value;

        address[] memory _path0 = new address[](2);
        _path0[0] = _wbaseCoin;
        _path0[1] = _xch0_t1;

        address[] memory _path1 = new address[](2);
        _path1[0] = _xch1_t0;
        _path1[1] = _wbaseCoin;

        // execute first swap
        dexSwap(_routerAddress0, _amountIn0, _path0, _percentage);

        // get ERC20 token contract
        IERC20 tokenContract = IERC20(_path0[1]);

        // get the amount of token recieved after swap
        uint256 _amountIn1 = tokenContract.balanceOf(address(this));

        // use that input amount to execute the next swap
        dexSwap(_routerAddress1, _amountIn1, _path1, _percentage);

        // get the amount of token recieved after swap
        uint256 _result = wbaseCoin.balanceOf(address(this));

        // withdraw to sender
        if (_trap == 1) {
            // send wrapped funds to msg.sender
            harvestERC20(_wbaseCoin);
        } else {
            // unwrap
            wbaseCoin.withdraw(_result);

            // send unwrapped funds to msg.sender
            withdrawBase();
        }

        // ensure that the trade doesn't end with less out than in
        uint256 _tolerance = 200000000000000000; // assuming a gas fee as high as 0.2
        require(_result > _amountIn0 + _tolerance, "False flag");
    }

    // retreive stored data
    function retrieve() public view returns (address[] memory) {
        return flashDEX;
    }

    // pancake callback function for flashswap
    function pancakeCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        // create variables
        address[] memory path = new address[](2);
        uint256 amountToken;
        uint256 amountBase;

        flashDEX = retrieve();
        address xch0_factory_address = flashDEX[0];
        address xch1_router_address = flashDEX[1];

        {
            // fetch the address of token0
            address token0 = IPair(msg.sender).token0();
            // fetch the address of token1
            address token1 = IPair(msg.sender).token1();
            // ensure that msg.sender is actually a V2 pair
            assert(
                msg.sender ==
                    UniswapV2Library.pairFor(
                        xch0_factory_address,
                        token0,
                        token1
                    )
            );
            // this strategy is unidirectional
            require(
                amount0 == 0 || amount1 == 0,
                "Either amount0 or amount1 should be zero"
            );
            path[0] = amount0 == 0 ? token0 : token1;
            path[1] = amount0 == 0 ? token1 : token0;
            amountToken = token0 == _wbaseCoin ? amount1 : amount0;
            amountBase = token0 == _wbaseCoin ? amount0 : amount1;
        }

        // ensure there's a wrapped token in the path
        assert(path[0] == _wbaseCoin || path[1] == _wbaseCoin);

        // uint256 slippage = 1; // 99/100

        if (amountToken > 0) {
            uint256 min_amount = abi.decode(data, (uint256)); // slippage parameter for V1, passed in by caller

            // get ERC20 token contract
            IERC20 tokenContract = IERC20(path[0]);

            // approve the router to send token to contract
            tokenContract.approve(xch1_router_address, amountToken);

            uint256 amountRequired = UniswapV2Library.getAmountsIn(
                xch0_factory_address,
                amountToken,
                path
            )[0];

            uint256 amountReceived = IRouter(xch1_router_address)
                .swapExactTokensForTokens(
                    amountToken,
                    min_amount,
                    path,
                    address(this),
                    block.timestamp
                )[1];

            // fail if we didn't get enough ETH back to repay our flash loan
            require(
                amountReceived > amountRequired,
                "Not enough to repay flash loan"
            );
            wbaseCoin.deposit{value: amountRequired}();
            // return WETH to pair and keep the rest!
            assert(wbaseCoin.transfer(msg.sender, amountReceived));
            assert(wbaseCoin.transfer(sender, amountReceived - amountRequired));
        } else {
            uint256 minTokens = abi.decode(data, (uint256)); // slippage parameter for V1, passed in by caller
            wbaseCoin.withdraw(amountBase);

            uint256 amountRequired = UniswapV2Library.getAmountsIn(
                xch0_factory_address,
                amountBase,
                path
            )[0];

            uint256 amountReceived = IRouter(xch1_router_address)
                .swapExactTokensForTokens(
                    amountBase,
                    minTokens,
                    path,
                    address(this),
                    block.timestamp
                )[1];

            // fail if we didn't get enough ETH back to repay our flash loan
            require(
                amountReceived > amountRequired,
                "Not enough to repay flash loan"
            );
            assert(wbaseCoin.transfer(msg.sender, amountRequired)); // return tokens to V2 pair
            assert(wbaseCoin.transfer(sender, amountReceived - amountRequired)); // keep the rest! (tokens)
        }
    }

    // function to borrow flashloan
    // one of the amounts need to be zero and the 'amount' that is not zero corresponds to the token to be borrowed
    function flashSwap(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        address dex_factory,
        address dex_router
    ) public onlyOwner {
        // save the addresses
        flashDEX = new address[](2);
        flashDEX[0] = dex_factory;
        flashDEX[1] = dex_router;

        address pairAddress = IFactory(dex_factory).getPair(token0, token1);
        require(pairAddress != address(0), "This pool does not exist");
        IPair(pairAddress).swap(amount0, amount1, address(this), new bytes(1));
    }
}
