pragma solidity ^0.4.16;

import "ds-math/math.sol";

contract OtcInterface {
    function sellAllAmount(address, uint, address, uint) returns (uint);
    function buyAllAmount(address, uint, address, uint) returns (uint);
    function getPayAmount(address, address, uint) returns (uint);
}

contract TokenInterface {
    function balanceOf(address) returns (uint);
    function trust(address, bool);
    function approve(address, uint);
    function transfer(address,uint);
    function transferFrom(address, address, uint);
    function deposit() payable;
    function withdraw(uint);
}

contract MatchingMarketProxy is DSMath {
    address eth;
    address sai;

    function withdrawAndSend(TokenInterface wethToken, uint wethAmt) internal {
        wethToken.withdraw(wethAmt);
        require(msg.sender.call.value(wethAmt)());
    }

    function sellAllAmount(OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface buyToken, uint minBuyAmt) public returns (uint buyAmt) {
        payToken.transferFrom(msg.sender, this, payAmt);
        payToken.approve(otc, payAmt);
        buyAmt = otc.sellAllAmount(payToken, payAmt, buyToken, minBuyAmt);
        buyToken.transfer(msg.sender, buyAmt);
    }

    function sellAllAmountPayEth(OtcInterface otc, TokenInterface wethToken, TokenInterface buyToken, uint minBuyAmt) public payable returns (uint buyAmt) {
        wethToken.deposit.value(msg.value)();
        wethToken.approve(otc, msg.value);
        buyAmt = otc.sellAllAmount(wethToken, msg.value, buyToken, minBuyAmt);
        buyToken.transfer(msg.sender, buyAmt);
    }

    function sellAllAmountBuyEth(OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface wethToken, uint minBuyAmt) public returns (uint wethAmt) {
        payToken.transferFrom(msg.sender, this, payAmt);
        payToken.approve(otc, payAmt);
        wethAmt = otc.sellAllAmount(payToken, payAmt, wethToken, minBuyAmt);
        withdrawAndSend(wethToken, wethAmt);
    }

    function buyAllAmount(OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface payToken, uint maxPayAmt) public returns (uint payAmt) {
        payToken.transferFrom(msg.sender, this, maxPayAmt);
        payToken.approve(otc, maxPayAmt);
        payAmt = otc.buyAllAmount(buyToken, buyAmt, payToken, maxPayAmt);
        buyToken.transfer(msg.sender, buyAmt);
        payToken.transfer(msg.sender, sub(maxPayAmt, payAmt));
    }

    function buyAllAmountPayEth(OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface wethToken) public payable returns (uint wethAmt) {
        // In this case user needs to send more ETH than a estimated value, then contract will send back the rest
        wethToken.deposit.value(msg.value)();
        wethToken.approve(otc, msg.value);
        wethAmt = otc.buyAllAmount(buyToken, buyAmt, wethToken, msg.value);
        withdrawAndSend(wethToken, sub(msg.value, wethAmt));
    }

    function buyAllAmountBuyEth(OtcInterface otc, TokenInterface wethToken, uint wethAmt, TokenInterface payToken, uint maxPayAmt) public returns (uint payAmt) {
        payToken.transferFrom(msg.sender, this, maxPayAmt);
        payToken.approve(otc, uint(-1));
        payAmt = otc.buyAllAmount(wethToken, wethAmt, payToken, maxPayAmt);
        withdrawAndSend(wethToken, wethAmt);
        payToken.transfer(msg.sender, sub(maxPayAmt, payAmt));
    }

    function() payable {}
}
