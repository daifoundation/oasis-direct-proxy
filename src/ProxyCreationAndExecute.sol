pragma solidity ^0.5.12;

import "./OasisDirectProxy.sol";

contract FactoryLike {
    function build(address) public returns (address payable);
}

contract ProxyCreationAndExecute is OasisDirectProxy {
    address wethToken;

    constructor(address wethToken_) public {
        wethToken = wethToken_;
    }

    function createAndSellAllAmount(
        address factory,
        address otc,
        address payToken,
        uint payAmt,
        address buyToken,
        uint minBuyAmt
    ) public returns (address payable proxy, uint buyAmt) {
        proxy = FactoryLike(factory).build(msg.sender);
        buyAmt = sellAllAmount(otc,payToken, payAmt, buyToken, minBuyAmt);
    }

    function createAndSellAllAmountPayEth(
        address factory,
        address otc,
        address buyToken,
        uint minBuyAmt
    ) public payable returns (address payable proxy, uint buyAmt) {
        proxy = FactoryLike(factory).build(msg.sender);
        buyAmt = sellAllAmountPayEth(otc, wethToken, buyToken, minBuyAmt);
    }

    function createAndSellAllAmountBuyEth(
        address factory,
        address otc,
        address payToken,
        uint payAmt,
        uint minBuyAmt
    ) public returns (address payable proxy, uint wethAmt) {
        proxy = FactoryLike(factory).build(msg.sender);
        wethAmt = sellAllAmountBuyEth(otc, payToken, payAmt, wethToken, minBuyAmt);
    }

    function createAndBuyAllAmount(
        address factory,
        address otc,
        address buyToken,
        uint buyAmt,
        address payToken,
        uint maxPayAmt
    ) public returns (address payable proxy, uint payAmt) {
        proxy = FactoryLike(factory).build(msg.sender);
        payAmt = buyAllAmount(otc, buyToken, buyAmt, payToken, maxPayAmt);
    }

    function createAndBuyAllAmountPayEth(
        address factory,
        address otc,
        address buyToken,
        uint buyAmt
    ) public payable returns (address payable proxy, uint wethAmt) {
        proxy = FactoryLike(factory).build(msg.sender);
        wethAmt = buyAllAmountPayEth(otc, buyToken, buyAmt, wethToken);
    }

    function createAndBuyAllAmountBuyEth(
        address factory,
        address otc,
        uint wethAmt,
        address payToken,
        uint maxPayAmt
    ) public returns (address payable proxy, uint payAmt) {
        proxy = FactoryLike(factory).build(msg.sender);
        payAmt = buyAllAmountBuyEth(otc, wethToken, wethAmt, payToken, maxPayAmt);
    }

    function() external payable {
        require(msg.sender == address(wethToken), "");
    }
}
