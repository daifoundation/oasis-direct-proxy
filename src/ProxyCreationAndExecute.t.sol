pragma solidity ^0.4.16;

import "./OasisDirectProxy.t.sol";
import "./ProxyCreationAndExecute.sol";

contract ProxyCreationAndExecuteTest is DSTest {
    ProxyCreationAndExecute creator;
    DSProxyFactory factory;
    MatchingMarket otc;
    WETH weth;
    DSToken mkr;
    FakeUser user;

    function setUp() public {
        weth = new WETH();
        mkr = new DSToken("MKR");

        creator = new ProxyCreationAndExecute();
        factory = new DSProxyFactory();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        otc.addTokenPairWhitelist(weth, mkr);
        weth.approve(otc);
        mkr.approve(otc);
        user = new FakeUser(otc);
        user.doApprove(weth);
        user.doApprove(mkr);
    }

    function createOffers(uint oQuantity, uint mkrAmount, uint wethAmount) public {
        for (uint i = 0; i < oQuantity; i ++) {
            user.doOffer(wethAmount / oQuantity, weth, mkrAmount / oQuantity, mkr);
        }
    }

    function testProxySellAll() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4000 ether);
        mkr.approve(creator, 4000 ether);
        assertEq(weth.balanceOf(this), 0); // Balance token to buy
        assertEq(mkr.balanceOf(this), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = msg.gas;
        var (proxy, buyAmt) = creator.createAndSellAllAmount(factory, OtcInterface(otc), TokenInterface(mkr), 4000 ether, TokenInterface(weth), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(weth.balanceOf(this), buyAmt); // Balance token bought
        assertEq(mkr.balanceOf(this), 0); // Balance token sold
        assertEq(proxy.owner(), this);
    }

    function testProxySellAllPayEth() public {
        uint initialBalance = this.balance;
        mkr.mint(6000 ether);
        mkr.transfer(user, 6000 ether);
        user.doOffer(3200 ether, mkr, 10 ether, weth);
        user.doOffer(2800 ether, mkr, 10 ether, weth);
        assertEq(mkr.balanceOf(this), 0); // Balance token to buy
        assertEq(this.balance, initialBalance); // Balance ETH
        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 5 / 10;
        uint startGas = msg.gas;
        var (proxy, buyAmt) = creator.createAndSellAllAmountPayEth.value(15 ether)(factory, OtcInterface(otc), TokenInterface(weth), TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(mkr.balanceOf(this), buyAmt); // Balance token bought
        assertEq(this.balance, initialBalance - 15 ether); // Balance ETH
        assertEq(proxy.owner(), this);
    }

    function testProxySellAllBuyEth() public {
        user.doDeposit.value(20 ether)(weth);
        user.doOffer(10 ether, weth, 3200 ether, mkr);
        user.doOffer(10 ether, weth, 2800 ether, mkr);
        uint initialBalance = this.balance;
        mkr.mint(4000 ether);
        mkr.approve(creator, 4000 ether);
        assertEq(this.balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(this), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = msg.gas;
        var (proxy, buyAmt) = creator.createAndSellAllAmountBuyEth(factory, OtcInterface(otc), TokenInterface(mkr), 4000 ether, TokenInterface(weth), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(this.balance, initialBalance + expectedResult); // Balance ETH
        assertEq(mkr.balanceOf(this), 0); // Balance token sold
        assertEq(proxy.owner(), this);
    }

    function testProxyBuyAll() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4400 ether);
        mkr.approve(creator, 4400 ether);
        assertEq(weth.balanceOf(this), 0); // Balance token to buy
        assertEq(mkr.balanceOf(this), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        var (proxy, payAmt) = creator.createAndBuyAllAmount(factory, OtcInterface(otc), TokenInterface(weth), 15 ether, TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(weth.balanceOf(this), 15 ether); // Balance token bought
        assertEq(mkr.balanceOf(this), 4400 ether - payAmt); // Balance token sold
        assertEq(proxy.owner(), this);
    }

    function testProxyBuyAllPayEth() public {
        uint initialBalance = this.balance;
        mkr.mint(6000 ether);
        mkr.transfer(user, 6000 ether);
        user.doOffer(3200 ether, mkr, 10 ether, weth);
        user.doOffer(2800 ether, mkr, 10 ether, weth);
        assertEq(mkr.balanceOf(this), 0); // Balance token to buy
        assertEq(this.balance, initialBalance); // Balance ETH
        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        uint startGas = msg.gas;
        var (proxy, payAmt) = creator.createAndBuyAllAmountPayEth.value(expectedResult)(factory, OtcInterface(otc), TokenInterface(mkr), 4600 ether, TokenInterface(weth));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(mkr.balanceOf(this), 4600 ether); // Balance token bought
        assertEq(this.balance, initialBalance - payAmt); // Balance ETH
        assertEq(proxy.owner(), this);
    }

    function testProxyBuyAllBuyEth() public {
        user.doDeposit.value(20 ether)(weth);
        user.doOffer(10 ether, weth, 3200 ether, mkr);
        user.doOffer(10 ether, weth, 2800 ether, mkr);
        uint initialBalance = this.balance;
        mkr.mint(4400 ether);
        mkr.approve(creator, 4400 ether);
        assertEq(this.balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(this), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        var (proxy, payAmt) = creator.createAndBuyAllAmountBuyEth(factory, OtcInterface(otc), TokenInterface(weth), 15 ether, TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(this.balance, initialBalance + 15 ether); // Balance ETH
        assertEq(mkr.balanceOf(this), 4400 ether - payAmt); // Balance token sold
        assertEq(proxy.owner(), this);
    }

    function() public payable {}
}
