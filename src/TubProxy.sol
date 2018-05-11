pragma solidity ^0.4.18;

import "ds-math/math.sol";

contract TokenInterface {
  function balanceOf(address) public returns (uint);
  function allowance(address, address) public returns (uint);
  function approve(address, uint) public;
  function transfer(address,uint) public returns (bool);
  function transferFrom(address, address, uint) public returns (bool);
  function deposit() public payable;
  function withdraw(uint) public;
}

contract TubInterface {
  function gem() public returns (address);
  function skr() public returns (address);
  function sai() public returns (address);
  function ask(uint) public returns (uint);
  function join(uint) public;
  function open() public returns (bytes32);
  function lock(bytes32, uint) public;
  function draw(bytes32, uint) public;
  function give(bytes32, address) public;
}

contract TubProxyEvents {
  event LogNewCup(address indexed lad, bytes32 cup);
}

contract TubProxy is DSMath, TubProxyEvents {
  function joinOpenAndDraw(TubInterface tub, uint withdrawAmount) public payable returns (bytes32 cup) {
    TokenInterface wethToken = TokenInterface(tub.gem());
    TokenInterface skr       = TokenInterface(tub.skr());
    TokenInterface sai       = TokenInterface(tub.sai());
    if (skr.allowance(address(this), tub) < msg.value) {
      skr.approve(tub, uint(-1));
    }
    if (sai.allowance(address(this), tub) < msg.value) {
      sai.approve(tub, uint(-1));
    }
    if (wethToken.allowance(address(this), tub) < msg.value) {
      wethToken.approve(tub, uint(-1));
    }
    wethToken.deposit.value(msg.value)();
    uint valueSkr = wdiv(msg.value, tub.ask(WAD));
    tub.join(valueSkr);
    cup = tub.open();
    tub.lock(cup, valueSkr);
    tub.draw(bytes32(cup), withdrawAmount);
    tub.give(cup, msg.sender);
    sai.transfer(msg.sender, withdrawAmount);
    LogNewCup(msg.sender, cup);
  }

  function() public payable {}
}
