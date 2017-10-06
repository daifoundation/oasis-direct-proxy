pragma solidity ^0.4.16;

import "ds-test/test.sol";
import "sai/sai.t.sol";
import "maker-otc/matching_market.sol";
import "./OasisDirectProxy.sol";

contract WETH is DSToken {
    function WETH() DSToken("WETH") {}

    function deposit() public payable {
        _balances[msg.sender] = add(_balances[msg.sender], msg.value);
        _supply = add(_supply, msg.value);
    }

    function withdraw(uint amount) public {
        _balances[msg.sender] = sub(_balances[msg.sender], amount);
        _supply = sub(_supply, amount);
        assert(msg.sender.call.value(amount)());
    }
}

contract OasisDirectProxyTest is SaiTestBase {
    OasisDirectProxy proxy;
    MatchingMarket otc;
    WETH weth;

    function setUp() public {
        super.setUp();
        weth = new WETH();
        proxy = new OasisDirectProxy();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        otc.addTokenPairWhitelist(gem, sai);
        otc.addTokenPairWhitelist(weth, sai);
        gem.trust(otc, true);
        sai.trust(otc, true);
        mom.setHat(1000000 ether);
        mom.setMat(ray(1.5 ether));
        tag.poke(bytes32(300 ether));
        gem.burn(100 ether);
    }

    function createOffers(uint oQuantity, uint saiAmount, uint gemAmount) public {
        for(uint i = 0; i < oQuantity; i ++) {
            otc.offer(gemAmount / oQuantity, gem, saiAmount / oQuantity, sai, 0);
        }
    }

    function testProxySellAll() public {
        gem.mint(20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        sai.mint(4000 ether);
        sai.transfer(proxy, 4000 ether);
        assertEq(gem.balanceOf(this), 0);
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmount(OtcInterface(otc), TokenInterface(sai), 4000 ether, TokenInterface(gem));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200);
        assertEq(gem.balanceOf(this), buyAmt);
    }

    function testProxySellAllPayEth() public {
        uint initialBalance = this.balance;
        sai.mint(6000 ether);
        otc.offer(3200 ether, sai, 10 ether, weth, 0);
        otc.offer(2800 ether, sai, 10 ether, weth, 0);
        assertEq(sai.balanceOf(this), 0);
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmountPayEth.value(15 ether)(OtcInterface(otc), TokenInterface(weth), TokenInterface(sai));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, 3200 ether * 10 / 10 + 2800 ether * 5 / 10);
        assertEq(sai.balanceOf(this), buyAmt);
        assertEq(this.balance, initialBalance - 15 ether);
    }

    function testProxySellAllBuyEth() public {
        weth.deposit.value(20 ether)();
        weth.approve(otc, uint(-1));
        otc.offer(10 ether, weth, 3200 ether, sai, 0);
        otc.offer(10 ether, weth, 2800 ether, sai, 0);
        uint initialBalance = this.balance;
        sai.mint(4000 ether);
        sai.transfer(proxy, 4000 ether);
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmountBuyEth(OtcInterface(otc), TokenInterface(sai), 4000 ether, TokenInterface(weth));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200);
        assertEq(this.balance, initialBalance + (10 ether * 2800 / 2800 + 10 ether * 1200 / 3200));
    }

    function testProxyBuyAll() public {
        gem.mint(20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        sai.mint(4400 ether);
        sai.transfer(proxy, 4400 ether);
        assertEq(gem.balanceOf(this), 0);
        uint startGas = msg.gas;
        uint payAmt = proxy.buyAllAmount(OtcInterface(otc), TokenInterface(gem), 15 ether, TokenInterface(sai));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, 2800 ether * 10 / 10 + 3200 ether * 5 / 10);
        assertEq(gem.balanceOf(this), 15 ether);
    }

    function testProxyBuyAllBuyEth() public {
        uint initialBalance = this.balance;
        sai.mint(6000 ether);
        otc.offer(3200 ether, sai, 10 ether, weth, 0);
        otc.offer(2800 ether, sai, 10 ether, weth, 0);
        assertEq(sai.balanceOf(this), 0);
        uint startGas = msg.gas;
        uint payAmt = proxy.buyAllAmountPayEth.value(15 ether)(OtcInterface(otc), TokenInterface(sai), 4000 ether, TokenInterface(weth));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(this.balance, initialBalance - payAmt);
    }

    function testProxyBuyAllPayEth() public {
        weth.deposit.value(20 ether)();
        weth.approve(otc, uint(-1));
        otc.offer(10 ether, weth, 3200 ether, sai, 0);
        otc.offer(10 ether, weth, 2800 ether, sai, 0);
        uint initialBalance = this.balance;
        sai.mint(4400 ether);
        sai.transfer(proxy, 4400 ether);
        uint startGas = msg.gas;
        uint sellAmt = proxy.buyAllAmountBuyEth(OtcInterface(otc), TokenInterface(weth), 15 ether, TokenInterface(sai));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(sellAmt, 2800 ether * 10 / 10 + 3200 ether * 5 / 10);
        assertEq(this.balance, initialBalance + 15 ether);
    }

    function testProxyMarginTradeOffersSamePrice() public {
        uint dif = 0;
        for (uint i = 1; i <= 30; i++) {
            gem.mint(200 ether);
            createOffers(i, 30000 ether, 100 ether); // Price: 300 SAI/ETH
            dif = 100 ether - (100 ether / i) * i;
            if (dif > 0) {
                createOffers(1, 300 * dif, dif);
            }
            assertEq(gem.balanceOf(this), 100 ether);
            gem.transfer(proxy, 100 ether);
            uint startGas = msg.gas;
            var cup = proxy.marginTrade(100 ether, 2 ether, TubInterface(tub), OtcInterface(otc));
            uint endGas = msg.gas;
            log_named_uint('# Orders', i);
            log_named_uint('Gas', startGas - endGas);
            var (,ink,) = tub.cups(cup);
            assertEq(rdiv(ink, tub.per()), 200 ether);
        }
    }

    function testProxyMarginTradeOffersDifferentPrices4Orders() public {
        gem.mint(200 ether);
        createOffers(1, 8990 ether, 30 ether);
        createOffers(1, 13000 ether, 40 ether);
        createOffers(1, 3100 ether, 10 ether);
        createOffers(1, 6050 ether, 20 ether);
        assertEq(gem.balanceOf(this), 100 ether);
        gem.transfer(proxy, 100 ether);
        uint startGas = msg.gas;
        var cup = proxy.marginTrade(100 ether, 2 ether, TubInterface(tub), OtcInterface(otc));
        uint endGas = msg.gas;
        // log_named_uint('# Orders', i);
        log_named_uint('Gas', startGas - endGas);
        var (,ink,) = tub.cups(cup);
        // log_named_uint('Ink', rdiv(ink, tub.per()));
        assertEq(rdiv(ink, tub.per()), 200 ether);
    }

    function testProxyMarginTradeOffersDifferentPrices10Orders() public {
        gem.mint(200 ether);
        createOffers(1, 1510 ether, 5 ether);
        createOffers(1, 1499 ether, 5 ether);
        createOffers(1, 1250 ether, 4 ether);
        createOffers(1, 6250 ether, 20 ether);
        createOffers(1, 920 ether, 3 ether);
        createOffers(1, 2850 ether, 10 ether);
        createOffers(1, 9500 ether, 30 ether);
        createOffers(1, 4800 ether, 16 ether);
        createOffers(1, 2150 ether, 7 ether);
        assertEq(gem.balanceOf(this), 100 ether);
        gem.transfer(proxy, 100 ether);
        uint startGas = msg.gas;
        var cup = proxy.marginTrade(100 ether, 2 ether, TubInterface(tub), OtcInterface(otc));
        uint endGas = msg.gas;
        // log_named_uint('# Orders', i);
        log_named_uint('Gas', startGas - endGas);
        var (,ink,) = tub.cups(cup);
        // log_named_uint('Ink', rdiv(ink, tub.per()));
        assertEq(rdiv(ink, tub.per()), 200 ether);
    }

    // function testGasOrderTake() public {
    //     uint oQuantity = 1;
    //     createOffers(oQuantity, 270000 ether, 900 ether);
    //     assertEq(gem.balanceOf(this), 100 ether);
    //     sai.mint(270000 ether);
    //     uint startGas = msg.gas;
    //     for(uint i = 1; i <= oQuantity; i ++) {
    //         otc.take(bytes32(i), uint128(900 ether / oQuantity));
    //     }
    //     uint endGas = msg.gas;
    //     log_named_uint('Gas take', startGas - endGas);
    //     assertEq(gem.balanceOf(this), 1000 ether);
    //     assertEq(sai.balanceOf(this), 270000 ether);
    // }

    // function testGasOrderOffer() public {
    //     createOffers(1, 270000 ether, 900 ether);
    //     assertEq(gem.balanceOf(this), 100 ether);
    //     sai.mint(270000 ether);
    //     uint startGas = msg.gas;
    //     otc.offer(270000 ether, sai, 900 ether, gem, 0);
    //     uint endGas = msg.gas;
    //     log_named_uint('Gas', startGas - endGas);
    //     assertEq(gem.balanceOf(this), 1000 ether);
    //     assertEq(sai.balanceOf(this), 270000 ether);
    // }

    function() payable {}
}
