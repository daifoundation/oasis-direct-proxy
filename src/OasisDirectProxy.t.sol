pragma solidity ^0.4.16;

import "ds-test/test.sol";
import "sai/sai.t.sol";
import "maker-otc/matching_market.sol";

import "./OasisDirectProxy.sol";

contract OasisDirectProxyTest is SaiTestBase {
    OasisDirectProxy proxy;
    MatchingMarket otc;

    function setUp() {
        super.setUp();
        proxy = new OasisDirectProxy();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        otc.addTokenPairWhitelist(gem, sai);
        gem.trust(otc, true);
        sai.trust(otc, true);
        mom.setHat(1000000 ether);
        mom.setMat(ray(1.5 ether));
        tag.poke(bytes32(300 ether));
        gem.burn(100 ether);
    }

    function createOffers(uint oQuantity, uint saiAmount, uint gemAmount) {
        for(uint i = 0; i < oQuantity; i ++) {
            otc.offer(gemAmount / oQuantity, gem, saiAmount / oQuantity, sai, 0);
        }
    }

    function testProxySellAll() {
        gem.mint(20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2900 ether, 10 ether);
        sai.mint(4000 ether);
        sai.transfer(proxy, 4000 ether);
        var buyAmt = proxy.sellAll(OtcInterface(otc), TokenInterface(gem), TokenInterface(sai), 4000 ether);
        assertEq(buyAmt, 10 ether * 2900 / 2900 + 10 ether * 1100 / 3200);
    }

    function testProxyMarginTradeOffersSamePrice() {
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

    function testProxyMarginTradeOffersDifferentPrices4Orders() {
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

    function testProxyMarginTradeOffersDifferentPrices10Orders() {
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

    // function testGasOrderTake() {
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

    // function testGasOrderOffer() {
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
}
