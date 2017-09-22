pragma solidity ^0.4.16;

import "ds-test/test.sol";

import "./OasisDirectProxy.sol";

contract OasisDirectProxyTest is DSTest {
    OasisDirectProxy proxy;

    function setUp() {
        proxy = new OasisDirectProxy();
    }

    function testFail_basic_sanity() {
        assert(false);
    }

    function test_basic_sanity() {
        assert(true);
    }
}
