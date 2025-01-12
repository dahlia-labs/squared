// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Squared } from "../src/core/Squared.sol";
import { Pair } from "../src/core/Pair.sol";
import { Position } from "../src/core/libraries/Position.sol";
import { TestHelper } from "./utils/TestHelper.sol";

contract AccruePositionInterestTest is TestHelper {
  event AccruePositionInterest(address indexed owner, uint256 rewardPerPosition);

  function setUp() external {
    _setUp();
  }

  function testNoPositionError() external {
    vm.expectRevert(Position.NoPositionError.selector);
    vm.prank(cuh);
    squared.accruePositionInterest();
  }

  function testNoTime() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.prank(cuh);
    squared.accruePositionInterest();

    (uint256 positionSize, uint256 rewardPerPositionPaid, uint256 tokensOwed) = squared.positions(cuh);
    assertEq(1 ether, positionSize);
    assertEq(0, rewardPerPositionPaid);
    assertEq(0, tokensOwed);
  }

  function testAccruePositionInterest() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.warp(365 days + 1);

    vm.prank(cuh);
    squared.accruePositionInterest();

    uint256 borrowRate = squared.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year
    uint256 token1Dilution = 10 * lpDilution; // same as rewardPerPosition because position size is 1

    (uint256 positionSize, uint256 rewardPerPositionPaid, uint256 tokensOwed) = squared.positions(cuh);
    assertEq(1 ether, positionSize);
    assertEq(token1Dilution, rewardPerPositionPaid);
    assertEq(token1Dilution, tokensOwed);
  }

  function testsquaredEmit() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.warp(365 days + 1);

    uint256 borrowRate = squared.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year
    uint256 token1Dilution = 10 * lpDilution; // same as rewardPerPosition because position size is 1

    vm.prank(cuh);
    vm.expectEmit(true, false, false, true, address(squared));
    emit AccruePositionInterest(cuh, token1Dilution);
    squared.accruePositionInterest();
  }
}
