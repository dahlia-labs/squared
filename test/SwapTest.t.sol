// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Squared } from "../src/core/Squared.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";

contract SwapTest is TestHelper {
  event Swap(uint256 amount0Out, uint256 amount1Out, uint256 amount0In, uint256 amount1In, address indexed to);

  function setUp() external {
    _setUp();
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
  }

  function testSwapFull() external {
    token0.mint(cuh, 24 ether);

    vm.prank(cuh);
    token0.approve(address(this), 24 ether);

    squared.swap(
      cuh,
      0,
      8 ether,
      abi.encode(
        SwapCallbackData({ token0: address(token0), token1: address(token1), amount0: 24 ether, amount1: 0, payer: cuh })
      )
    );

    // check user balances
    assertEq(0, token0.balanceOf(cuh));
    assertEq(8 ether, token1.balanceOf(cuh));

    // check squared storage slots
    assertEq(25 ether, squared.reserve0());
    assertEq(0, squared.reserve1());
  }

  function testUnderPay() external {
    token0.mint(cuh, 23 ether);

    vm.prank(cuh);
    token0.approve(address(this), 23 ether);

    vm.expectRevert(Pair.InvariantError.selector);
    squared.swap(
      cuh,
      0,
      8 ether,
      abi.encode(
        SwapCallbackData({ token0: address(token0), token1: address(token1), amount0: 23 ether, amount1: 0, payer: cuh })
      )
    );
  }

  function testEmit() external {
    token0.mint(cuh, 24 ether);

    vm.prank(cuh);
    token0.approve(address(this), 24 ether);

    vm.expectEmit(true, false, false, true, address(squared));
    emit Swap(0, 8 ether, 24 ether, 0, cuh);
    squared.swap(
      cuh,
      0,
      8 ether,
      abi.encode(
        SwapCallbackData({ token0: address(token0), token1: address(token1), amount0: 24 ether, amount1: 0, payer: cuh })
      )
    );
  }
}
