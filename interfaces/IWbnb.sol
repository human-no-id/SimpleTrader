pragma solidity ^0.8.0;

interface IWbnb {
    receive() external payable;

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function totalSupply() external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function balanceOf(address owner) external view returns (uint256 balance);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}
