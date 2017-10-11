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
    WETH gem;

    function setUp() public {
        gem = new WETH();
        sai = new DSToken("SAI");
        sin = new DSToken("SIN");
        skr = new DSToken("SKR");
        tag = new DSValue();
        vox = new SaiVox();
        tap = new SaiTap();
        tub = new SaiTub(sai, sin, skr, gem, tag, vox, tap);
        top = new SaiTop(tub, tap);
        tap.turn(tub);
        dad = new DSGuard();
        mom = new SaiMom(tub, tap, vox);
        super.configureAuth();
        sai.trust(tub, true);
        skr.trust(tub, true);
        gem.trust(tub, true);
        sai.trust(tap, true);
        skr.trust(tap, true);
        
        proxy = new OasisDirectProxy();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        otc.addTokenPairWhitelist(gem, sai);
        gem.trust(otc, true);
        sai.trust(otc, true);
        mom.setHat(1000000 ether);
        mom.setMat(ray(1.5 ether));
        tag.poke(bytes32(300 ether));
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
        sai.transfer(proxy, 4000 ether);
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
        sai.transfer(proxy, 4000 ether);
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
        sai.transfer(proxy, 4400 ether);
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
        uint payAmt = proxy.buyAllAmountPayEth.value(15 ether)(OtcInterface(otc), TokenInterface(sai), 4600 ether, TokenInterface(gem), expectedResult);
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
        sai.transfer(proxy, 4400 ether);
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        uint sellAmt = proxy.buyAllAmountBuyEth(OtcInterface(otc), TokenInterface(gem), 15 ether, TokenInterface(sai), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(sellAmt, expectedResult);
        assertEq(this.balance, initialBalance + 15 ether);
    }

    function testProxyMarginNow() public {
        gem.deposit.value(20 ether)();
        otc.offer(10 ether, gem, 3200 ether, sai, 0);
        otc.offer(10 ether, gem, 2800 ether, sai, 0);
        uint initialBalance = this.balance;
        var cup = tub.open();
        tub.give(cup, proxy);
        uint startGas = msg.gas;
        var (ethAmount, saiDrawn) = proxy.marginNow.value(10 ether)(TubInterface(tub), OtcInterface(otc), cup, ray(1.7 ether), 99999 ether, 0);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(saiDrawn, rdiv(rmul(rdiv(ray(10 ether), ray(1.7 ether)), uint(tub.pip().read())), tub.vox().par()));
        assertEq(this.balance, initialBalance - 10 ether + ethAmount);
    }

    function testProxyMarginTradeOffersSamePrice() public {
        uint dif = 0;
        for (uint i = 1; i <= 30; i++) {
            gem.mint(100 ether);
            createOffers(i, 30000 ether, 100 ether); // Price: 300 SAI/ETH
            dif = 100 ether - (100 ether / i) * i;
            if (dif > 0) {
                createOffers(1, 300 * dif, dif);
            }
            assertEq(gem.balanceOf(this), 0);
            uint startGas = msg.gas;
            var cup = proxy.marginTrade.value(100 ether)(2 ether, TubInterface(tub), OtcInterface(otc));
            uint endGas = msg.gas;
            log_named_uint('# Orders', i);
            log_named_uint('Gas', startGas - endGas);
            var (lad, ink, ) = tub.cups(cup);
            assertEq(rdiv(ink, tub.per()), 200 ether);
            assertEq(lad, this);
        }
    }

    function testProxyMarginTradeOffersDifferentPrices4Orders() public {
        gem.mint(100 ether);
        createOffers(1, 8990 ether, 30 ether);
        createOffers(1, 13000 ether, 40 ether);
        createOffers(1, 3100 ether, 10 ether);
        createOffers(1, 6050 ether, 20 ether);
        assertEq(gem.balanceOf(this), 0);
        uint startGas = msg.gas;
        var cup = proxy.marginTrade.value(100 ether)(2 ether, TubInterface(tub), OtcInterface(otc));
        uint endGas = msg.gas;
        // log_named_uint('# Orders', i);
        log_named_uint('Gas', startGas - endGas);
        var (lad, ink, ) = tub.cups(cup);
        // log_named_uint('Ink', rdiv(ink, tub.per()));
        assertEq(rdiv(ink, tub.per()), 200 ether);
        assertEq(lad, this);
    }

    function testProxyMarginTradeOffersDifferentPrices10Orders() public {
        gem.mint(100 ether);
        createOffers(1, 1510 ether, 5 ether);
        createOffers(1, 1499 ether, 5 ether);
        createOffers(1, 1250 ether, 4 ether);
        createOffers(1, 6250 ether, 20 ether);
        createOffers(1, 920 ether, 3 ether);
        createOffers(1, 2850 ether, 10 ether);
        createOffers(1, 9500 ether, 30 ether);
        createOffers(1, 4800 ether, 16 ether);
        createOffers(1, 2150 ether, 7 ether);
        assertEq(gem.balanceOf(this), 0 ether);
        uint startGas = msg.gas;
        var cup = proxy.marginTrade.value(100 ether)(2 ether, TubInterface(tub), OtcInterface(otc));
        uint endGas = msg.gas;
        // log_named_uint('# Orders', i);
        log_named_uint('Gas', startGas - endGas);
        var (lad, ink, ) = tub.cups(cup);
        // log_named_uint('Ink', rdiv(ink, tub.per()));
        assertEq(rdiv(ink, tub.per()), 200 ether);
        assertEq(lad, this);
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
