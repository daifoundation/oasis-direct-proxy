pragma solidity ^0.4.16;

import "./TubProxy.sol";
import "ds-proxy/proxy.sol";
import "sai/tub.sol";

contract ProxyCreationAndExecute is TubProxy {
  TokenInterface wethToken;

  function ProxyCreationAndExecute(address wethToken_) {
    wethToken = TokenInterface(wethToken_);
  }

  function createAndJoinOpenDraw(DSProxyFactory factory, SaiTub tub, uint withdrawAmount) public payable returns (DSProxy proxy, bytes32 cup) {
    proxy = factory.build(msg.sender);
    cup = joinOpenAndDraw(tub, wethToken, withdrawAmount);
  }

  function() public payable {
    require(msg.sender == address(wethToken));
  }
}
