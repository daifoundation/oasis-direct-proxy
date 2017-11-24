pragma solidity ^0.4.16;

import "./OasisDirectProxy.sol";
import "ds-proxy/proxy.sol";

contract ProxyCreationAndExecute is OasisDirectProxy {

    function createProxy(DSProxyFactory factory) internal returns (DSProxy proxy) {
        proxy = factory.build();
        proxy.setOwner(msg.sender);
    }

    function createAndSellAllAmount(DSProxyFactory factory, OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface buyToken, uint minBuyAmt) public returns (DSProxy proxy, uint buyAmt) {
        proxy = createProxy(factory);
        buyAmt = sellAllAmount(otc, payToken, payAmt, buyToken, minBuyAmt);
    }

    function createAndSellAllAmountPayEth(DSProxyFactory factory, OtcInterface otc, TokenInterface wethToken, TokenInterface buyToken, uint minBuyAmt) public payable returns (DSProxy proxy, uint buyAmt) {
        proxy = createProxy(factory);
        buyAmt = sellAllAmountPayEth(otc, wethToken, buyToken, minBuyAmt);
    }

    function createAndSellAllAmountBuyEth(DSProxyFactory factory, OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface wethToken, uint minBuyAmt) public returns (DSProxy proxy, uint wethAmt) {
        proxy = createProxy(factory);
        wethAmt = sellAllAmountBuyEth(otc, payToken, payAmt, wethToken, minBuyAmt);
    }

    function createAndBuyAllAmount(DSProxyFactory factory, OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface payToken, uint maxPayAmt) public returns (DSProxy proxy, uint payAmt) {
        proxy = createProxy(factory);
        payAmt = buyAllAmount(otc, buyToken, buyAmt, payToken, maxPayAmt);
    }

    function createAndBuyAllAmountPayEth(DSProxyFactory factory, OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface wethToken) public payable returns (DSProxy proxy, uint wethAmt) {
        proxy = createProxy(factory);
        wethAmt = buyAllAmountPayEth(otc, buyToken, buyAmt, wethToken);
    }

    function createAndBuyAllAmountBuyEth(DSProxyFactory factory, OtcInterface otc, TokenInterface wethToken, uint wethAmt, TokenInterface payToken, uint maxPayAmt) public returns (DSProxy proxy, uint payAmt) {
        proxy = createProxy(factory);
        payAmt = buyAllAmountBuyEth(otc, wethToken, wethAmt, payToken, maxPayAmt);
    }
}
