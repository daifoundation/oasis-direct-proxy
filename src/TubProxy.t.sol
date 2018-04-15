pragma solidity ^0.4.16;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "ds-value/value.sol";
import "ds-roles/roles.sol";
import "sai/tub.sol";
import "sai/fab.sol";
import "sai/weth9.sol";

import "./TubProxy.sol";

contract PIT { }
contract OasisDirectProxyTest is DSTest {
  TubProxy proxy;
  WETH9 weth;
  SaiTub tub;
  DSToken skr;
  DSToken sai;

  function setUp() public {
    proxy = new TubProxy();
    weth = new WETH9();

    GemFab gemFab = new GemFab();
    VoxFab voxFab = new VoxFab();
    TubFab tubFab = new TubFab();
    TapFab tabFab = new TapFab();
    TopFab tobFab = new TopFab();
    MomFab momFab = new MomFab();
    DadFab dadFab = new DadFab();

    DaiFab daiFab = new DaiFab(
      gemFab,
      voxFab,
      tubFab,
      tabFab,
      tobFab,
      momFab,
      dadFab
    );
    DSRoles roles = new DSRoles();
    roles.setRootUser(this, true);

    daiFab.makeTokens();
    daiFab.makeVoxTub(
      DSToken(weth),
      new DSToken('GOV'),
      new DSValue(),
      new DSValue(),
      new PIT()
    );
    daiFab.makeTapTop();
    daiFab.configParams();
    daiFab.verifyParams();
    daiFab.configAuth(roles);

    tub = daiFab.tub();
    sai = tub.sai();
    skr = tub.skr();

    // tub setup
    tub.pip().poke(bytes32(1 ether));
    daiFab.mom().setCap(50000000000000000000000000);
  }

  function testJoinOpenAndDraw() public {
    uint initialBalance = address(this).balance;

    // Sanity Checks
    assertEq(weth.balanceOf(proxy), 0);
    assertEq(skr.balanceOf(proxy), 0);
    assertEq(sai.balanceOf(proxy), 0);
    assertEq(address(this).balance, initialBalance); // Balance ETH

    // Execute
    uint startGas = gasleft();
    bytes32 cup = proxy.joinOpenAndDraw.value(10 ether)(SaiTub(tub), TokenInterface(weth), 1 ether);
    uint endGas = gasleft();
    log_named_uint('Gas', startGas - endGas);

    // Assertions
    assertEq(address(this).balance, initialBalance - 10 ether);
    var (lad,) = tub.cups(bytes32(tub.cupi()));
    assertEq(lad, address(proxy));
    assertEq(sai.balanceOf(proxy), 1 ether);
  }

  function() public payable {}
}
