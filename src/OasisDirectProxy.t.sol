pragma solidity >=0.5.0;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "maker-otc/matching_market.sol";
import "ds-proxy/proxy.sol";
import "./OasisDirectProxy.sol";

contract WETH is DSToken {
    constructor() DSToken("WETH") public {}

    function deposit() public payable {
        _balances[msg.sender] = add(_balances[msg.sender], msg.value);
        _supply = add(_supply, msg.value);
    }

    function withdraw(uint amount) public {
        _balances[msg.sender] = sub(_balances[msg.sender], amount);
        _supply = sub(_supply, amount);
        (bool success,) = msg.sender.call.value(amount)("");
        require(success, "");
    }
}

contract FakeUser {
    MatchingMarket otc;

    constructor(MatchingMarket otc_) public {
        otc = otc_;
    }

    function doApprove(address token) public {
        ERC20(token).approve(address(otc), uint(-1));
    }

    function doLimitOffer(uint amount1, address token1, uint amount2, address token2) public {
        otc.limitOffer(amount1, ERC20(token1), amount2, ERC20(token2), false, 0);
    }

    function doDeposit(address token) public payable {
        WETH(token).deposit.value(msg.value)();
    }
}

contract OasisDirectProxyTest is DSTest {
    OasisDirectProxy oasisProxy;
    MatchingMarket otc;
    WETH weth;
    DSToken mkr;
    FakeUser user;
    DSProxy proxy;

    function setUp() public {
        weth = new WETH();
        mkr = new DSToken("MKR");

        oasisProxy = new OasisDirectProxy();
        otc = new MatchingMarket(uint64(now + 1 weeks));
        weth.approve(address(otc));
        mkr.approve(address(otc));
        user = new FakeUser(otc);
        user.doApprove(address(weth));
        user.doApprove(address(mkr));

        DSProxyFactory factory = new DSProxyFactory();
        proxy = DSProxy(factory.build());
    }

    function sellAllAmount(address, address, uint, address, uint) external returns (bytes memory) {
        return proxy.execute(address(oasisProxy), msg.data);
    }

    function sellAllAmountPayEth(address, address, address, uint) external payable {
        (bool success,) = address(proxy).call.value(msg.value)(abi.encodeWithSignature("execute(address,bytes)", address(oasisProxy), msg.data));
        require(success, "");
    }

    function sellAllAmountBuyEth(address, address, uint, address, uint) external returns (bytes memory) {
        return proxy.execute(address(oasisProxy), msg.data);
    }

    function buyAllAmount(address, address, uint, address, uint) external returns (bytes memory) {
        return proxy.execute(address(oasisProxy), msg.data);
    }

    function buyAllAmountPayEth(address, address, uint, address) external payable {
        (bool success,) = address(proxy).call.value(msg.value)(abi.encodeWithSignature("execute(address,bytes)", address(oasisProxy), msg.data));
        require(success, "");
    }

    function buyAllAmountBuyEth(address, address, uint, address, uint) external returns (bytes memory) {
        return proxy.execute(address(oasisProxy), msg.data);
    }

    function createOffers(uint oQuantity, uint mkrAmount, uint wethAmount) public {
        for (uint i = 0; i < oQuantity; i ++) {
            user.doLimitOffer(wethAmount / oQuantity, address(weth), mkrAmount / oQuantity, address(mkr));
        }
    }

    function testProxySellAll() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4000 ether);
        mkr.approve(address(oasisProxy), 4000 ether);
        assertEq(weth.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(mkr.balanceOf(address(this)), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = gasleft();
        uint buyAmt = oasisProxy.sellAllAmount(OtcInterface(address(otc)), TokenInterface(address(mkr)), 4000 ether, TokenInterface(address(weth)), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(weth.balanceOf(address(this)), buyAmt); // Balance token bought
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token sold
    }

    function testProxySellAll2() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4000 ether);
        mkr.approve(address(proxy), 4000 ether);
        assertEq(weth.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(mkr.balanceOf(address(this)), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = gasleft();
        bytes memory response = this.sellAllAmount(address(otc), address(mkr), 4000 ether, address(weth), expectedResult);
        uint endGas = gasleft();
        uint buyAmt;
        assembly {
            buyAmt := mload(add(response, 32))
        }
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(weth.balanceOf(address(this)), buyAmt); // Balance token bought
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token sold
    }

    function testProxySellAllPayEth() public {
        uint initialBalance = address(this).balance;
        mkr.mint(6000 ether);
        mkr.transfer(address(user), 6000 ether);
        user.doLimitOffer(3200 ether, address(mkr), 10 ether, address(weth));
        user.doLimitOffer(2800 ether, address(mkr), 10 ether, address(weth));
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(address(this).balance, initialBalance); // Balance ETH
        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 5 / 10;
        uint startGas = gasleft();
        uint buyAmt = oasisProxy.sellAllAmountPayEth.value(15 ether)(OtcInterface(address(otc)), TokenInterface(address(weth)), TokenInterface(address(mkr)), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(mkr.balanceOf(address(this)), buyAmt); // Balance token bought
        assertEq(address(this).balance, initialBalance - 15 ether); // Balance ETH
    }

    function testProxySellAllPayEth2() public {
        uint initialBalance = address(this).balance;
        mkr.mint(6000 ether);
        mkr.transfer(address(user), 6000 ether);
        user.doLimitOffer(3200 ether, address(mkr), 10 ether, address(weth));
        user.doLimitOffer(2800 ether, address(mkr), 10 ether, address(weth));
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(address(this).balance, initialBalance); // Balance ETH
        uint expectedResult = 3200 ether * 10 / 10 + 2800 ether * 5 / 10;
        uint buyAmt = mkr.balanceOf(address(this));
        uint startGas = gasleft();
        this.sellAllAmountPayEth.value(15 ether)(address(otc), address(weth), address(mkr), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint("Gas", startGas - endGas);
        buyAmt = mkr.balanceOf(address(this)) - buyAmt;
        assertEq(buyAmt, expectedResult);
        assertEq(mkr.balanceOf(address(this)), buyAmt); // Balance token bought
        assertEq(address(this).balance, initialBalance - 15 ether); // Balance ETH
    }

    function testProxySellAllBuyEth() public {
        user.doDeposit.value(20 ether)(address(weth));
        user.doLimitOffer(10 ether, address(weth), 3200 ether, address(mkr));
        user.doLimitOffer(10 ether, address(weth), 2800 ether, address(mkr));
        uint initialBalance = address(this).balance;
        mkr.mint(4000 ether);
        mkr.approve(address(oasisProxy), 4000 ether);
        assertEq(address(this).balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = gasleft();
        uint buyAmt = oasisProxy.sellAllAmountBuyEth(OtcInterface(address(otc)), TokenInterface(address(mkr)), 4000 ether, TokenInterface(address(weth)), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(address(this).balance, initialBalance + expectedResult); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token sold
    }

    function testProxySellAllBuyEth2() public {
        user.doDeposit.value(20 ether)(address(weth));
        user.doLimitOffer(10 ether, address(weth), 3200 ether, address(mkr));
        user.doLimitOffer(10 ether, address(weth), 2800 ether, address(mkr));
        uint initialBalance = address(this).balance;
        mkr.mint(4000 ether);
        mkr.approve(address(proxy), 4000 ether);
        assertEq(address(this).balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4000 ether); // Balance token to sell
        uint expectedResult = 10 ether * 2800 / 2800 + 10 ether * 1200 / 3200;
        uint startGas = gasleft();
        bytes memory response = this.sellAllAmountBuyEth(address(otc), address(mkr), 4000 ether, address(weth), expectedResult);
        uint endGas = gasleft();
        uint buyAmt;
        assembly {
            buyAmt := mload(add(response, 32))
        }
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(buyAmt, expectedResult);
        assertEq(address(this).balance, initialBalance + expectedResult); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token sold
    }

    function testProxyBuyAll() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4400 ether);
        mkr.approve(address(oasisProxy), 4400 ether);
        assertEq(weth.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(mkr.balanceOf(address(this)), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = gasleft();
        uint payAmt = oasisProxy.buyAllAmount(OtcInterface(address(otc)), TokenInterface(address(weth)), 15 ether, TokenInterface(address(mkr)), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(weth.balanceOf(address(this)), 15 ether); // Balance token bought
        assertEq(mkr.balanceOf(address(this)), 4400 ether - payAmt); // Balance token sold
    }

    function testProxyBuyAll2() public {
        weth.mint(20 ether);
        weth.transfer(address(user), 20 ether);
        createOffers(1, 3200 ether, 10 ether);
        createOffers(1, 2800 ether, 10 ether);
        mkr.mint(4400 ether);
        mkr.approve(address(proxy), 4400 ether);
        assertEq(weth.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(mkr.balanceOf(address(this)), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = gasleft();
        bytes memory response = this.buyAllAmount(address(otc), address(weth), 15 ether, address(mkr), expectedResult);
        uint endGas = gasleft();
        uint payAmt;
        assembly {
            payAmt := mload(add(response, 32))
        }
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(weth.balanceOf(address(this)), 15 ether); // Balance token bought
        assertEq(mkr.balanceOf(address(this)), 4400 ether - payAmt); // Balance token sold
    }

    function testProxyBuyAllPayEth() public {
        uint initialBalance = address(this).balance;
        mkr.mint(6000 ether);
        mkr.transfer(address(user), 6000 ether);
        user.doLimitOffer(3200 ether, address(mkr), 10 ether, address(weth));
        user.doLimitOffer(2800 ether, address(mkr), 10 ether, address(weth));
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(address(this).balance, initialBalance); // Balance ETH
        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        uint startGas = gasleft();
        uint payAmt = oasisProxy.buyAllAmountPayEth.value(expectedResult)(OtcInterface(address(otc)), TokenInterface(address(mkr)), 4600 ether, TokenInterface(address(weth)));
        uint endGas = gasleft();
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(mkr.balanceOf(address(this)), 4600 ether); // Balance token bought
        assertEq(address(this).balance, initialBalance - payAmt); // Balance ETH
    }

    function testProxyBuyAllPayEth2() public {
        uint initialBalance = address(this).balance;
        mkr.mint(6000 ether);
        mkr.transfer(address(user), 6000 ether);
        user.doLimitOffer(3200 ether, address(mkr), 10 ether, address(weth));
        user.doLimitOffer(2800 ether, address(mkr), 10 ether, address(weth));
        assertEq(mkr.balanceOf(address(this)), 0); // Balance token to buy
        assertEq(address(this).balance, initialBalance); // Balance ETH
        uint expectedResult = 10 ether * 3200 / 3200 + 10 ether * 1400 / 2800;
        uint payAmt = address(this).balance;
        uint startGas = gasleft();
        this.buyAllAmountPayEth.value(expectedResult)(address(otc), address(mkr), 4600 ether, address(weth));
        uint endGas = gasleft();
        emit log_named_uint("Gas", startGas - endGas);
        payAmt = payAmt - address(this).balance;
        assertEq(payAmt, expectedResult);
        assertEq(mkr.balanceOf(address(this)), 4600 ether); // Balance token bought
        assertEq(address(this).balance, initialBalance - payAmt); // Balance ETH
    }

    function testProxyBuyAllBuyEth() public {
        user.doDeposit.value(20 ether)(address(weth));
        user.doLimitOffer(10 ether, address(weth), 3200 ether, address(mkr));
        user.doLimitOffer(10 ether, address(weth), 2800 ether, address(mkr));
        uint initialBalance = address(this).balance;
        mkr.mint(4400 ether);
        mkr.approve(address(oasisProxy), 4400 ether);
        assertEq(address(this).balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = gasleft();
        uint payAmt = oasisProxy.buyAllAmountBuyEth(OtcInterface(address(otc)), TokenInterface(address(weth)), 15 ether, TokenInterface(address(mkr)), expectedResult);
        uint endGas = gasleft();
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(address(this).balance, initialBalance + 15 ether); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4400 ether - payAmt); // Balance token sold
    }

    function testProxyBuyAllBuyEth2() public {
        user.doDeposit.value(20 ether)(address(weth));
        user.doLimitOffer(10 ether, address(weth), 3200 ether, address(mkr));
        user.doLimitOffer(10 ether, address(weth), 2800 ether, address(mkr));
        uint initialBalance = address(this).balance;
        mkr.mint(4400 ether);
        mkr.approve(address(proxy), 4400 ether);
        assertEq(address(this).balance, initialBalance); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4400 ether); // Balance token to sell
        uint expectedResult = 2800 ether * 10 / 10 + 3200 ether * 5 / 10;
        uint startGas = gasleft();
        bytes memory response = this.buyAllAmountBuyEth(address(otc), address(weth), 15 ether, address(mkr), expectedResult);
        uint endGas = gasleft();
        uint payAmt;
        assembly {
            payAmt := mload(add(response, 32))
        }
        emit log_named_uint("Gas", startGas - endGas);
        assertEq(payAmt, expectedResult);
        assertEq(address(this).balance, initialBalance + 15 ether); // Balance ETH
        assertEq(mkr.balanceOf(address(this)), 4400 ether - payAmt); // Balance token sold
    }

    function() external payable {}
}
