pragma solidity ^0.4.16;

import "ds-thing/thing.sol";

contract OtcInterface {
    function sellAllAmount(address, uint, address) returns (uint);
    function buyAllAmount(address, uint, address) returns (uint);
    function getPayAmount(address, address, uint) returns (uint);
}

contract TokenInterface {
    function balanceOf(address) returns (uint);
    function trust(address, bool);
    function approve(address, uint);
    function transfer(address,uint);
    function deposit() payable;
    function withdraw(uint);
}

contract TubInterface {
    function open() returns (bytes32);
    function join(uint);
    function lock(bytes32, uint);
    function draw(bytes32, uint);
    function gem() returns (TokenInterface);
    function skr() returns (TokenInterface);
    function sai() returns (TokenInterface);
    function vox() returns (VoxInterface);
    function mat() returns (uint);
    function per() returns (uint);
    function pip() returns (PipInterface);
}

contract VoxInterface {
    function par() returns (uint);
}

contract PipInterface {
    function read() returns (bytes32);
}

contract OasisDirectProxy is DSThing {
    address eth;
    address sai;

    function withdrawAndSend(TokenInterface wethToken, uint wethAmt) internal {
        wethToken.withdraw(wethAmt);
        assert(msg.sender.call.value(wethAmt)());
    }

    function sellAllAmount(OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface buyToken) public returns (uint buyAmt) {
        payToken.approve(otc, uint(-1));
        buyAmt = otc.sellAllAmount(payToken, payAmt, buyToken);
        buyToken.transfer(msg.sender, buyAmt);
    }

    function sellAllAmountPayEth(OtcInterface otc, TokenInterface wethToken, TokenInterface buyToken) public payable returns (uint buyAmt) {
        wethToken.deposit.value(msg.value)();
        buyAmt = sellAllAmount(otc, wethToken, msg.value, buyToken);
    }

    function sellAllAmountBuyEth(OtcInterface otc, TokenInterface payToken, uint payAmt, TokenInterface wethToken) public returns (uint wethAmt) {
        payToken.approve(otc, uint(-1));
        wethAmt = otc.sellAllAmount(payToken, payAmt, wethToken);
        withdrawAndSend(wethToken, wethAmt);
    }

    function buyAllAmount(OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface payToken) public returns (uint payAmt) {
        payToken.approve(otc, uint(-1));
        payAmt = otc.buyAllAmount(buyToken, buyAmt, payToken);
        buyToken.transfer(msg.sender, buyAmt);
    }

    function buyAllAmountPayEth(OtcInterface otc, TokenInterface buyToken, uint buyAmt, TokenInterface wethToken) public payable returns (uint wethAmt) {
        // In this case user needs to send more ETH than a estimated value, then contract will send back the rest
        wethToken.deposit.value(msg.value)();
        wethAmt = buyAllAmount(otc, buyToken, buyAmt, wethToken);
        withdrawAndSend(wethToken, sub(msg.value, wethAmt));
    }

    function buyAllAmountBuyEth(OtcInterface otc, TokenInterface wethToken, uint wethAmt, TokenInterface payToken) public returns (uint payAmt) {
        payToken.approve(otc, uint(-1));
        payAmt = otc.buyAllAmount(wethToken, wethAmt, payToken);
        withdrawAndSend(wethToken, wethAmt);
    }

    function marginTrade(uint amount, uint leverage, TubInterface tub, OtcInterface otc) public returns (bytes32 cup) {
        // tub.gem().trust(tub, true);
        // tub.skr().trust(tub, true);
        // tub.sai().trust(otc, true);
        tub.gem().approve(tub, uint(-1));
        tub.skr().approve(tub, uint(-1));
        tub.sai().approve(otc, uint(-1));

        uint totSaiNeeded = otc.getPayAmount(tub.sai(), tub.gem(), wmul(amount, sub(leverage, WAD))); // Check in the actual market how much total SAI is needed to get this desired WETH value
        uint saiDrawn = 0; // Total SAI already drawn
        uint initialSaiBalance = tub.sai().balanceOf(this); // Check actual balance of SAI of the proxy
        cup = tub.open(); // Open a new CDP

        while (saiDrawn < totSaiNeeded) { // While there is still SAI pending to be drawn
            uint saiToDraw = min(
                            rdiv(
                                rmul(
                                    rdiv(amount * 10 ** 9, tub.mat()),
                                    uint(tub.pip().read())
                                    ),
                                tub.vox().par()
                                ), // max value of SAI that can be drawn with the locked amount
                            sub(totSaiNeeded, saiDrawn) // value of SAI still needed to be drawn
                            );
            tub.join(amount); // Convert WETH to SKR (first time will be the initial amount, next cycles will on the amount bought)
            tub.lock(cup, rmul(tub.per(), amount)); // Lock SKR in the CDP created
            tub.draw(cup, saiToDraw); // Draw SAI
            saiDrawn = add(saiDrawn, saiToDraw); // Add SAI drawn to accumulator
            amount = otc.sellAllAmount(tub.sai(), sub(tub.sai().balanceOf(this), initialSaiBalance), tub.gem()); // Sell SAI, buy WETH, returns amount of WETH bought
        }
        tub.join(amount); // Convert last WETH to SKR
        tub.lock(cup, rmul(tub.per(), amount)); // Lock last SKR
    }

    function() payable {}
}
