pragma solidity ^0.4.16;

import "ds-math/math.sol";
import "ds-token/token.sol";
import "sai/tub.sol";

contract TokenInterface {
  function balanceOf(address) public returns (uint);
  function allowance(address, address) public returns (uint);
  function approve(address, uint) public;
  function transfer(address,uint) public returns (bool);
  function transferFrom(address, address, uint) public returns (bool);
  function deposit() public payable;
  function withdraw(uint) public;
}

contract TubProxy is DSMath {

  function joinOpenAndDraw(SaiTub tub, TokenInterface wethToken, uint withdrawAmount) public payable returns (bytes32 cup) {
    // convert eth -> weth
    // TubProxy has msg.value
    // TubProxy gives allownce to Tub to manage its Weth balance
    // proxy deposits msg.value on behalf of user
    wethToken.deposit.value(msg.value)();

    // approvals
    if (wethToken.allowance(this, tub) < msg.value) {
      wethToken.approve(tub, uint(-1));
    }
    if (tub.skr().allowance(this, tub) < msg.value) {
      tub.skr().approve(tub, uint(-1));
    }
    if (tub.sai().allowance(this, tub) < msg.value) {
      tub.sai().approve(tub, uint(-1));
    }

    // // join tub and convert to peth
    // // since proxy has weth, need to convert to peth with join
    // // proxy now has SKR
    // transfering fails when tranfer from proxy to tub
    // allowance?

    uint skRate = tub.ask(WAD);
    uint valueSkr = wdiv(msg.value, skRate);
    tub.join(valueSkr);

    // open CDP
    cup = tub.open();

    // lock collateral
    tub.lock(cup, min(valueSkr, tub.skr().balanceOf(this)));

    // withdraw dai
    // require(withdraw amount is above liquidation threshold)
    tub.draw(cup, withdrawAmount);

    tub.give(cup, msg.sender);
  }

  function() public payable {}
}
