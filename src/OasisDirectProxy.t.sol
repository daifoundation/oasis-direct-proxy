pragma solidity ^0.4.16;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "maker-otc/matching_market.sol";
import "./OasisDirectProxy.sol";

contract WETH is DSToken {
    function WETH() DSToken("WETH") public {}

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

contract FakeUser {
    MatchingMarket otc;

    function FakeUser(MatchingMarket otc_) public {
        otc = otc_;
    }

    function doApprove(address token) public {
        ERC20(token).approve(otc, uint(-1));
    }

    function doOffer(uint amount1, address token1, uint amount2, address token2) public {
        otc.offer(amount1, ERC20(token1), amount2, ERC20(token2), 0);
    }

    function doDeposit(address token) public payable {
        WETH(token).deposit.value(msg.value)();
    }
}

contract OasisDirectProxyTest is DSTest {
    OasisDirectProxy proxy;
    MatchingMarket otc;
    WETH weth;
    DSToken mkr;
    FakeUser user;

    function setUp() public {
        weth = new WETH();
        mkr = new DSToken("MKR");

        proxy = new OasisDirectProxy();
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
        mkr.approve(proxy, 4000 ether);
        assertEq(weth.balanceOf(this), 0); // Balance token to buy
        assertEq(mkr.balanceOf(this), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmount(OtcInterface(otc), TokenInterface(mkr), 4000 ether, TokenInterface(weth), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(weth.balanceOf(this), buyAmt); // Balance token bought
        assertEq(mkr.balanceOf(this), 0); // Balance token sold
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
        uint buyAmt = proxy.sellAllAmountPayEth.value(15 ether)(OtcInterface(otc), TokenInterface(weth), TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(mkr.balanceOf(this), buyAmt); // Balance token bought
        assertEq(this.balance, initialBalance - 15 ether); // Balance ETH
    }

    function testProxySellAllBuyEth() public {
        user.doDeposit.value(20 ether)(weth);
        user.doOffer(10 ether, weth, 3200 ether, mkr);
        user.doOffer(10 ether, weth, 2800 ether, mkr);
        uint initialBalance = this.balance;
        mkr.mint(4000 ether);
        mkr.approve(proxy, 4000 ether);
        assertEq(this.balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(this), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = msg.gas;
        uint buyAmt = proxy.sellAllAmountBuyEth(OtcInterface(otc), TokenInterface(mkr), 4000 ether, TokenInterface(weth), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(this.balance, initialBalance + expectedResult); // Balance ETH
        assertEq(mkr.balanceOf(this), 0); // Balance token sold
    }

    function testProxyBuyAll() public {
        weth.mint(20 ether);
        weth.transfer(user, 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4400 ether);
        mkr.approve(proxy, 4400 ether);
        assertEq(weth.balanceOf(this), 0); // Balance token to buy
        assertEq(mkr.balanceOf(this), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        uint payAmt = proxy.buyAllAmount(OtcInterface(otc), TokenInterface(weth), 15 ether, TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(weth.balanceOf(this), 15 ether); // Balance token bought
        assertEq(mkr.balanceOf(this), 4400 ether - payAmt); // Balance token sold
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
        uint payAmt = proxy.buyAllAmountPayEth.value(expectedResult)(OtcInterface(otc), TokenInterface(mkr), 4600 ether, TokenInterface(weth));
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(mkr.balanceOf(this), 4600 ether); // Balance token bought
        assertEq(this.balance, initialBalance - payAmt); // Balance ETH
    }

    function testProxyBuyAllBuyEth() public {
        user.doDeposit.value(20 ether)(weth);
        user.doOffer(10 ether, weth, 3200 ether, mkr);
        user.doOffer(10 ether, weth, 2800 ether, mkr);
        uint initialBalance = this.balance;
        mkr.mint(4400 ether);
        mkr.approve(proxy, 4400 ether);
        assertEq(this.balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(this), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = msg.gas;
        uint payAmt = proxy.buyAllAmountBuyEth(OtcInterface(otc), TokenInterface(weth), 15 ether, TokenInterface(mkr), expectedResult);
        uint endGas = msg.gas;
        log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(this.balance, initialBalance + 15 ether); // Balance ETH
        assertEq(mkr.balanceOf(this), 4400 ether - payAmt); // Balance token sold
    }

    function() public payable {}
}
