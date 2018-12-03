pragma solidity >=0.5.0;

import "ds-math/math.sol";

contract OtcInterface {
    function sellAllAmount(address, uint, address, uint) public returns (uint);
    function buyAllAmount(address, uint, address, uint) public returns (uint);
    function getPayAmount(address, address, uint) public view returns (uint);
}

contract TokenInterface {
    function balanceOf(address) public returns (uint);
    function allowance(address, address) public returns (uint);
    function approve(address, uint) public;
    function transfer(address,uint) public returns (bool);
    function transferFrom(address, address, uint) public returns (bool);
    function deposit() public payable;
    function withdraw(uint) public;
}

contract OasisDirectProxy is DSMath {
    function withdrawAndSend(TokenInterface wethToken, uint wethAmt) internal {
        wethToken.withdraw(wethAmt);
        (bool success,) = msg.sender.call.value(wethAmt)("");
        require(success, "withdraw-failed");
    }

    function sellAllAmount(
        OtcInterface otc,
        TokenInterface payToken,
        uint payAmt,
        TokenInterface buyToken,
        uint minBuyAmt
    ) public returns (uint buyAmt) {
        require(payToken.transferFrom(msg.sender, address(this), payAmt), "payToken-transferFrom-fail");
        if (payToken.allowance(address(this), address(otc)) < payAmt) {
            payToken.approve(address(otc), uint(-1));
        }
        buyAmt = otc.sellAllAmount(address(payToken), payAmt, address(buyToken), minBuyAmt);
        require(buyToken.transfer(msg.sender, buyAmt), "buyToken-transfer-fail");
    }

    function sellAllAmountPayEth(
        OtcInterface otc,
        TokenInterface wethToken,
        TokenInterface buyToken,
        uint minBuyAmt
    ) public payable returns (uint buyAmt) {
        wethToken.deposit.value(msg.value)();
        if (wethToken.allowance(address(this), address(otc)) < msg.value) {
            wethToken.approve(address(otc), uint(-1));
        }
        buyAmt = otc.sellAllAmount(address(wethToken), msg.value, address(buyToken), minBuyAmt);
        require(buyToken.transfer(msg.sender, buyAmt), "buyToken-transfer-fail");
    }

    function sellAllAmountBuyEth(
        OtcInterface otc,
        TokenInterface payToken,
        uint payAmt,
        TokenInterface wethToken,
        uint minBuyAmt
    ) public returns (uint wethAmt) {
        require(payToken.transferFrom(msg.sender, address(this), payAmt), "payToken-transferFrom-fail");
        if (payToken.allowance(address(this), address(otc)) < payAmt) {
            payToken.approve(address(otc), uint(-1));
        }
        wethAmt = otc.sellAllAmount(address(payToken), payAmt, address(wethToken), minBuyAmt);
        withdrawAndSend(wethToken, wethAmt);
    }

    function buyAllAmount(
        OtcInterface otc,
        TokenInterface buyToken,
        uint buyAmt,
        TokenInterface payToken,
        uint maxPayAmt
    ) public returns (uint payAmt) {
        require(payToken.transferFrom(msg.sender, address(this), maxPayAmt), "payToken-transferFrom-fail");
        if (payToken.allowance(address(this), address(otc)) < maxPayAmt) {
            payToken.approve(address(otc), uint(-1));
        }
        payAmt = otc.buyAllAmount(address(buyToken), buyAmt, address(payToken), maxPayAmt);
        require(buyToken.transfer(msg.sender, min(buyAmt, buyToken.balanceOf(address(this)))), "buyToken-transfer-fail"); // To avoid rounding issues we check the minimum value
        require(payToken.transfer(msg.sender, sub(maxPayAmt, payAmt)), "payToken-transfer-fail");
    }

    function buyAllAmountPayEth(
        OtcInterface otc,
        TokenInterface buyToken,
        uint buyAmt,
        TokenInterface wethToken
    ) public payable returns (uint wethAmt) {
        // In this case user needs to send more ETH than a estimated value, then contract will send back the rest
        wethToken.deposit.value(msg.value)();
        if (wethToken.allowance(address(this), address(otc)) < msg.value) {
            wethToken.approve(address(otc), uint(-1));
        }
        wethAmt = otc.buyAllAmount(address(buyToken), buyAmt, address(wethToken), msg.value);
        require(buyToken.transfer(msg.sender, min(buyAmt, buyToken.balanceOf(address(this)))), "buyToken-transfer-fail"); // To avoid rounding issues we check the minimum value
        withdrawAndSend(wethToken, sub(msg.value, wethAmt));
    }

    function buyAllAmountBuyEth(
        OtcInterface otc,
        TokenInterface wethToken,
        uint wethAmt,
        TokenInterface payToken,
        uint maxPayAmt
    ) public returns (uint payAmt) {
        require(payToken.transferFrom(msg.sender, address(this), maxPayAmt), "payToken-transferFrom-fail");
        if (payToken.allowance(address(this), address(otc)) < maxPayAmt) {
            payToken.approve(address(otc), uint(-1));
        }
        payAmt = otc.buyAllAmount(address(wethToken), wethAmt, address(payToken), maxPayAmt);
        withdrawAndSend(wethToken, wethAmt);
        require(payToken.transfer(msg.sender, sub(maxPayAmt, payAmt)), "payToken-transfer-fail");
    }

    function() external payable {}
}
