pragma solidity ^0.4.16;

import "./OasisDirectProxy.sol";
import "ds-proxy/proxy.sol";

contract ProxyCreationAndExecute is OasisDirectProxy {
    TokenInterface wethToken;

    function ProxyCreationAndExecute(address wethToken_) {
        wethToken = TokenInterface(wethToken_);
    }

    function createAndSellAllAmount(DSProxyFactory factory, OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface buyToken, uint minBuyAmt) public returns (DSProxy proxy, uint buyAmt) {
        proxy = factory.build(msg.sender);
        buyAmt = sellAllAmount(otc, payToken, payAmt, buyToken, minBuyAmt);
    }

    function createAndSellAllAmountPayEth(DSProxyFactory factory, OtcInterface otc, TokenInterface buyToken, uint minBuyAmt) public payable returns (DSProxy proxy, uint buyAmt) {
        proxy = factory.build(msg.sender);
        buyAmt = sellAllAmountPayEth(otc, wethToken, buyToken, minBuyAmt);
    }

    function createAndSellAllAmountBuyEth(DSProxyFactory factory, OtcInterface otc, TokenInterface payToken, uint payAmt, uint minBuyAmt) public returns (DSProxy proxy, uint wethAmt) {
        proxy = factory.build(msg.sender);
        wethAmt = sellAllAmountBuyEth(otc, payToken, payAmt, wethToken, minBuyAmt);
    }

    function createAndBuyAllAmount(DSProxyFactory factory, OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface payToken, uint maxPayAmt) public returns (DSProxy proxy, uint payAmt) {
        proxy = factory.build(msg.sender);
        payAmt = buyAllAmount(otc, buyToken, buyAmt, payToken, maxPayAmt);
    }

    function createAndBuyAllAmountPayEth(DSProxyFactory factory, OtcInterface otc, TokenInterface buyToken, uint buyAmt) public payable returns (DSProxy proxy, uint wethAmt) {
        proxy = factory.build(msg.sender);
        wethAmt = buyAllAmountPayEth(otc, buyToken, buyAmt, wethToken);
    }

    function createAndBuyAllAmountBuyEth(DSProxyFactory factory, OtcInterface otc, uint wethAmt, TokenInterface payToken, uint maxPayAmt) public returns (DSProxy proxy, uint payAmt) {
        proxy = factory.build(msg.sender);
        payAmt = buyAllAmountBuyEth(otc, wethToken, wethAmt, payToken, maxPayAmt);
    }

    function() public payable {
        if (msg.sender != address(wethToken)) {
            revert();
        }
    }
}
