// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "../src/core/Factory.sol";
import { Squared } from "../src/core/Squared.sol";
import { Test } from "forge-std/Test.sol";

contract ImmutableStateTest is Test {
  Factory public factory;
  Squared public squared;

  function setUp() external {
    factory = new Factory();
    squared = Squared(factory.createSquared(address(1), address(2), 18, 18, 1e18));
  }

  function testImmutableState() external {
    assertEq(address(1), squared.token0());
    assertEq(address(2), squared.token1());
    assertEq(1, squared.token0Scale());
    assertEq(1, squared.token1Scale());
    assertEq(1e18, squared.upperBound());
  }
}
