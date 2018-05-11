pragma solidity ^0.4.18;

import "./TubProxy.sol";
import "ds-proxy/proxy.sol";

contract ProxyCreationAndExecute is TubProxy {
  TubInterface tub;

  function ProxyCreationAndExecute(address _tub) {
    tub = TubInterface(_tub);
  }

  function createAndJoinOpenDraw(DSProxyFactory factory, uint withdrawAmount) public payable returns (DSProxy proxy, bytes32 cup) {
    proxy = factory.build(msg.sender);
    cup = joinOpenAndDraw(tub, withdrawAmount);
  }

  function() public payable {
    require(msg.sender == address(tub.gem()));
  }
}
