// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "../src/core/Factory.sol";
import { Squared } from "../src/core/Squared.sol";
import { Test } from "forge-std/Test.sol";

import { SquaredAddress } from "../src/periphery/libraries/SquaredAddress.sol";

contract FactoryTest is Test {
  event SquaredCreated(
    address indexed token0,
    address indexed token1,
    uint256 token0Scale,
    uint256 token1Scale,
    uint256 indexed upperBound,
    address squared
  );

  Factory public factory;

  function setUp() external {
    factory = new Factory();
  }

  function testGetSquared() external {
    address squared = factory.createSquared(address(1), address(2), 18, 18, 1e18);

    assertEq(squared, factory.getSquared(address(1), address(2), 18, 18, 1e18));
  }

  function testDeployAddress() external {
    address squaredEstimate = SquaredAddress.computeAddress(address(factory), address(1), address(2), 18, 18, 1e18);

    address squared = factory.createSquared(address(1), address(2), 18, 18, 1e18);

    assertEq(squared, squaredEstimate);
  }

  function testSameTokenError() external {
    vm.expectRevert(Factory.SameTokenError.selector);
    factory.createSquared(address(1), address(1), 18, 18, 1e18);
  }

  function testZeroAddressError() external {
    vm.expectRevert(Factory.ZeroAddressError.selector);
    factory.createSquared(address(0), address(1), 18, 18, 1e18);

    vm.expectRevert(Factory.ZeroAddressError.selector);
    factory.createSquared(address(1), address(0), 18, 18, 1e18);
  }

  function testDeployedError() external {
    factory.createSquared(address(1), address(2), 18, 18, 1e18);

    vm.expectRevert(Factory.DeployedError.selector);
    factory.createSquared(address(1), address(2), 18, 18, 1e18);
  }

  function helpParametersZero() private {
    (address token0, address token1, uint256 token0Scale, uint256 token1Scale, uint256 upperBound) =
      factory.parameters();

    assertEq(address(0), token0);
    assertEq(address(0), token1);
    assertEq(0, token0Scale);
    assertEq(0, token1Scale);
    assertEq(0, upperBound);
  }

  function testParameters() external {
    helpParametersZero();

    factory.createSquared(address(1), address(2), 18, 18, 1e18);

    helpParametersZero();
  }

  function testEmit() external {
    address squaredEstimate = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              address(factory),
              keccak256(abi.encode(address(1), address(2), 18, 18, 1e18)),
              keccak256(type(Squared).creationCode)
            )
          )
        )
      )
    );
    vm.expectEmit(true, true, true, true, address(factory));
    emit SquaredCreated(address(1), address(2), 18, 18, 1e18, squaredEstimate);
    factory.createSquared(address(1), address(2), 18, 18, 1e18);
  }
}
