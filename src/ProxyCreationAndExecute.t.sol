pragma solidity ^0.5.12;

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

        creator = new ProxyCreationAndExecute(address(weth));
        factory = new DSProxyFactory();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        weth.approve(address(otc));
        mkr.approve(address(otc));
        user = new FakeUser(otc);
        user.doApprove(address(weth));
        user.doApprove(address(mkr));
    }

    function createOffers(uint oQuantity, uint mkrAmount, uint wethAmount) public {
        for (uint i = 0; i < oQuantity; i ++) {
            user.doOffer(wethAmount / oQuantity, address(weth), mkrAmount / oQuantity, address(mkr));
        }
    }

    function testProxySellAll() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4000 ether);
        mkr.approve(address(creator), 4000 ether);
        assertEq(weth.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(mkr.balanceOf(address(this)), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = gasleft();
        (address payable proxy, uint buyAmt) = creator.createAndSellAllAmount(address(factory), address(otc), address(mkr), 4000 ether, address(weth), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(weth.balanceOf(address(this)), buyAmt); // Balance token bought
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token sold
        assertEq(DSProxy(proxy).owner(), address(this));
    }

    function testProxySellAllPayEth() public {
        uint initialBalance = address(this).balance;
        mkr.mint(6000 ether);
        mkr.transfer(address(user), 6000 ether);
        user.doOffer(3200 ether, address(mkr), 10 ether, address(weth));
        user.doOffer(2800 ether, address(mkr), 10 ether, address(weth));
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(address(this).balance, initialBalance); // Balance ETH
        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 5 / 10;
        uint startGas = gasleft();
        (address payable proxy, uint buyAmt) = creator.createAndSellAllAmountPayEth.value(15 ether)(address(factory), address(otc), address(mkr), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(mkr.balanceOf(address(this)), buyAmt); // Balance token bought
        assertEq(address(this).balance, initialBalance - 15 ether); // Balance ETH
        assertEq(DSProxy(proxy).owner(), address(this));
    }

    function testProxySellAllBuyEth() public {
        user.doDeposit.value(20 ether)(address(weth));
        user.doOffer(10 ether, address(weth), 3200 ether, address(mkr));
        user.doOffer(10 ether, address(weth), 2800 ether, address(mkr));
        uint initialBalance = address(this).balance;
        mkr.mint(4000 ether);
        mkr.approve(address(creator), 4000 ether);
        assertEq(address(this).balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = gasleft();
        (address payable proxy, uint buyAmt) = creator.createAndSellAllAmountBuyEth(address(factory), address(otc), address(mkr), 4000 ether, expectedResult);
        uint endGas = gasleft();
        emit log_named_uint('Gas', startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(address(this).balance, initialBalance + expectedResult); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token sold
        assertEq(DSProxy(proxy).owner(), address(this));
    }

    function testProxyBuyAll() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4400 ether);
        mkr.approve(address(creator), 4400 ether);
        assertEq(weth.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(mkr.balanceOf(address(this)), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = gasleft();
        (address payable proxy, uint payAmt) = creator.createAndBuyAllAmount(address(factory), address(otc), address(weth), 15 ether, address(mkr), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(weth.balanceOf(address(this)), 15 ether); // Balance token bought
        assertEq(mkr.balanceOf(address(this)), 4400 ether - payAmt); // Balance token sold
        assertEq(DSProxy(proxy).owner(), address(this));
    }

    function testProxyBuyAllPayEth() public {
        uint initialBalance = address(this).balance;
        mkr.mint(6000 ether);
        mkr.transfer(address(user), 6000 ether);
        user.doOffer(3200 ether, address(mkr), 10 ether, address(weth));
        user.doOffer(2800 ether, address(mkr), 10 ether, address(weth));
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(address(this).balance, initialBalance); // Balance ETH
        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        uint startGas = gasleft();
        (address payable proxy, uint payAmt) = creator.createAndBuyAllAmountPayEth.value(expectedResult)(address(factory), address(otc), address(mkr), 4600 ether);
        uint endGas = gasleft();
        emit log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(mkr.balanceOf(address(this)), 4600 ether); // Balance token bought
        assertEq(address(this).balance, initialBalance - payAmt); // Balance ETH
        assertEq(DSProxy(proxy).owner(), address(this));
    }

    function testProxyBuyAllBuyEth() public {
        user.doDeposit.value(20 ether)(address(weth));
        user.doOffer(10 ether, address(weth), 3200 ether, address(mkr));
        user.doOffer(10 ether, address(weth), 2800 ether, address(mkr));
        uint initialBalance = address(this).balance;
        mkr.mint(4400 ether);
        mkr.approve(address(creator), 4400 ether);
        assertEq(address(this).balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = gasleft();
        (address payable proxy, uint payAmt) = creator.createAndBuyAllAmountBuyEth(address(factory), address(otc), 15 ether, address(mkr), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint('Gas', startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(address(this).balance, initialBalance + 15 ether); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4400 ether - payAmt); // Balance token sold
        assertEq(DSProxy(proxy).owner(), address(this));
    }

    function testFailSendFunds() public {
        (bool ok,) = address(creator).call.value(1 ether)("");
        assert(ok);
    }

    function() external payable {}
}
