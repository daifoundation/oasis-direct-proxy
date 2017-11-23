pragma solidity ^0.4.16;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "maker-otc/matching_market.sol";
import "./MatchingMarketProxy.sol";

contract WETH is DSToken {
    function WETH() DSToken("WETH") {}

    function deposit() public payable {
        _balances[msg.sender] = add(_balances[msg.sender], msg.value);
        _supply = add(_supply, msg.value);
    }

    function withdraw(uint amount) public {
        _balances[msg.sender] = sub(_balances[msg.sender], amount);
        _supply = sub(_supply, amount);
        require(msg.sender.call.value(amount)());
    }
}

contract MatchingMarketProxyTest is DSTest {
    MatchingMarketProxy proxy;
    MatchingMarket otc;
    WETH weth;
    DSToken mkr;

    function setUp() public {
        weth = new WETH();
        mkr = new DSToken("MKR");

        proxy = new MatchingMarketProxy();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        otc.addTokenPairWhitelist(weth, mkr);
        weth.approve(otc);
        mkr.approve(otc);
    }

    function createOffers(uint oQuantity, uint mkrAmount, uint wethAmount) public {
        for (uint i = 0; i < oQuantity; i ++) {
            otc.offer(wethAmount / oQuantity, weth, mkrAmount / oQuantity, mkr, 0);
        }
    }

    function testProxySellAll() public {
        weth.mint(20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4000 ether);
        mkr.approve(proxy, 4000 ether);
        assertEq(weth.balanceOf(this), 0);
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmount(OtcInterface(otc), TokenInterface(mkr), 4000 ether, TokenInterface(weth), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(weth.balanceOf(this), buyAmt);
    }

    function testProxySellAllPayEth() public {
        uint initialBalance = this.balance;
        mkr.mint(6000 ether);
        otc.offer(3200 ether, mkr, 10 ether, weth, 0);
        otc.offer(2800 ether, mkr, 10 ether, weth, 0);
        assertEq(mkr.balanceOf(this), 0);
        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 5 / 10;
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmountPayEth.value(15 ether)(OtcInterface(otc), TokenInterface(weth), TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(mkr.balanceOf(this), buyAmt);
        assertEq(this.balance, initialBalance - 15 ether);
    }

    function testProxySellAllBuyEth() public {
        weth.deposit.value(20 ether)();
        otc.offer(10 ether, weth, 3200 ether, mkr, 0);
        otc.offer(10 ether, weth, 2800 ether, mkr, 0);
        uint initialBalance = this.balance;
        mkr.mint(4000 ether);
        mkr.approve(proxy, 4000 ether);
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmountBuyEth(OtcInterface(otc), TokenInterface(mkr), 4000 ether, TokenInterface(weth), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(this.balance, initialBalance + expectedResult);
    }

    function testProxyBuyAll() public {
        weth.mint(20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4400 ether);
        mkr.approve(proxy, 4400 ether);
        assertEq(weth.balanceOf(this), 0);
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        uint payAmt = proxy.buyAllAmount(OtcInterface(otc), TokenInterface(weth), 15 ether, TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(weth.balanceOf(this), 15 ether);
    }

    function testProxyBuyAllPayEth() public {
        uint initialBalance = this.balance;
        mkr.mint(6000 ether);
        otc.offer(3200 ether, mkr, 10 ether, weth, 0);
        otc.offer(2800 ether, mkr, 10 ether, weth, 0);
        assertEq(mkr.balanceOf(this), 0);
        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        uint startGas = msg.gas;
        uint payAmt = proxy.buyAllAmountPayEth.value(expectedResult)(OtcInterface(otc), TokenInterface(mkr), 4600 ether, TokenInterface(weth));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(this.balance, initialBalance - payAmt);
    }

    function testProxyBuyAllBuyEth() public {
        weth.deposit.value(20 ether)();
        otc.offer(10 ether, weth, 3200 ether, mkr, 0);
        otc.offer(10 ether, weth, 2800 ether, mkr, 0);
        uint initialBalance = this.balance;
        mkr.mint(4400 ether);
        mkr.approve(proxy, 4400 ether);
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        uint sellAmt = proxy.buyAllAmountBuyEth(OtcInterface(otc), TokenInterface(weth), 15 ether, TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(sellAmt, expectedResult);
        assertEq(this.balance, initialBalance + 15 ether);
    }

    function() payable {}
}
