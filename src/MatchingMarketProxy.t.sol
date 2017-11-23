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

contract MatchingMarketProxyTest {
    MatchingMarketProxy proxy;
    MatchingMarket otc;
    WETH gem;

    function setUp() public {
        gem = new WETH();
        sai = new DSToken("SAI");

        proxy = new MatchingMarketProxy();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        otc.addTokenPairWhitelist(gem, sai);
        gem.approve(otc);
        sai.approve(otc);
    }

    function createOffers(uint oQuantity, uint saiAmount, uint gemAmount) public {
        for (uint i = 0; i < oQuantity; i ++) {
            otc.offer(gemAmount / oQuantity, gem, saiAmount / oQuantity, sai, 0);
        }
    }

    function testProxySellAll() public {
        gem.mint(20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        sai.mint(4000 ether);
        sai.approve(proxy, 4000 ether);
        assertEq(gem.balanceOf(this), 0);
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmount(OtcInterface(otc), TokenInterface(sai), 4000 ether, TokenInterface(gem), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(gem.balanceOf(this), buyAmt);
    }

    function testProxySellAllPayEth() public {
        uint initialBalance = this.balance;
        sai.mint(6000 ether);
        otc.offer(3200 ether, sai, 10 ether, gem, 0);
        otc.offer(2800 ether, sai, 10 ether, gem, 0);
        assertEq(sai.balanceOf(this), 0);
        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 5 / 10;
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmountPayEth.value(15 ether)(OtcInterface(otc), TokenInterface(gem), TokenInterface(sai), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(sai.balanceOf(this), buyAmt);
        assertEq(this.balance, initialBalance - 15 ether);
    }

    function testProxySellAllBuyEth() public {
        gem.deposit.value(20 ether)();
        otc.offer(10 ether, gem, 3200 ether, sai, 0);
        otc.offer(10 ether, gem, 2800 ether, sai, 0);
        uint initialBalance = this.balance;
        sai.mint(4000 ether);
        sai.approve(proxy, 4000 ether);
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmountBuyEth(OtcInterface(otc), TokenInterface(sai), 4000 ether, TokenInterface(gem), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(this.balance, initialBalance + expectedResult);
    }

    function testProxyBuyAll() public {
        gem.mint(20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        sai.mint(4400 ether);
        sai.approve(proxy, 4400 ether);
        assertEq(gem.balanceOf(this), 0);
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        uint payAmt = proxy.buyAllAmount(OtcInterface(otc), TokenInterface(gem), 15 ether, TokenInterface(sai), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(gem.balanceOf(this), 15 ether);
    }

    function testProxyBuyAllPayEth() public {
        uint initialBalance = this.balance;
        sai.mint(6000 ether);
        otc.offer(3200 ether, sai, 10 ether, gem, 0);
        otc.offer(2800 ether, sai, 10 ether, gem, 0);
        assertEq(sai.balanceOf(this), 0);
        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        uint startGas = msg.gas;
        uint payAmt = proxy.buyAllAmountPayEth.value(expectedResult)(OtcInterface(otc), TokenInterface(sai), 4600 ether, TokenInterface(gem));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(this.balance, initialBalance - payAmt);
    }

    function testProxyBuyAllBuyEth() public {
        gem.deposit.value(20 ether)();
        otc.offer(10 ether, gem, 3200 ether, sai, 0);
        otc.offer(10 ether, gem, 2800 ether, sai, 0);
        uint initialBalance = this.balance;
        sai.mint(4400 ether);
        sai.approve(proxy, 4400 ether);
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        uint sellAmt = proxy.buyAllAmountBuyEth(OtcInterface(otc), TokenInterface(gem), 15 ether, TokenInterface(sai), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(sellAmt, expectedResult);
        assertEq(this.balance, initialBalance + 15 ether);
    }

    function() payable {}
}
