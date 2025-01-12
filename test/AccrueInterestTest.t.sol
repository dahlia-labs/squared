// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Squared } from "../src/core/Squared.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";

contract AccrueInterestTest is TestHelper {
  event AccrueInterest(uint256 timeElapsed, uint256 collateral, uint256 liquidity);

  function setUp() external {
    _setUp();
  }

  function testAccrueNoLiquidity() external {
    squared.accrueInterest();

    assertEq(1, squared.lastUpdate());
    assertEq(0, squared.rewardPerPositionStored());
    assertEq(0, squared.totalLiquidityBorrowed());
  }

  function testAccrueNoTime() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    squared.accrueInterest();

    assertEq(1, squared.lastUpdate());
    assertEq(0, squared.rewardPerPositionStored());
    assertEq(0.5 ether, squared.totalLiquidityBorrowed());
  }

  function testAccrueInterest() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.warp(365 days + 1);

    squared.accrueInterest();

    uint256 borrowRate = squared.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year
    uint256 token1Dilution = 10 * lpDilution; // same as rewardPerPosition because position size is 1

    assertEq(365 days + 1, squared.lastUpdate());
    assertEq(0.5 ether - lpDilution, squared.totalLiquidityBorrowed());
    assertEq(token1Dilution, squared.rewardPerPositionStored());
  }

  function testMaxDilution() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.warp(730 days + 1);

    squared.accrueInterest();

    assertEq(730 days + 1, squared.lastUpdate());
    assertEq(0, squared.totalLiquidityBorrowed());
    assertEq(5 ether, squared.rewardPerPositionStored());
  }

  function testsquaredEmit() external {
    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
    _mint(cuh, cuh, 5 ether);

    vm.warp(365 days + 1);

    uint256 borrowRate = squared.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year
    uint256 token1Dilution = 10 * lpDilution; // same as rewardPerPosition because position size is 1

    vm.expectEmit(false, false, false, true, address(squared));
    emit AccrueInterest(365 days, token1Dilution, lpDilution);
    squared.accrueInterest();
  }

  function testNonStandardDecimals() external {
    token1Scale = 9;

    squared = Squared(factory.createSquared(address(token0), address(token1), token0Scale, token1Scale, upperBound));

    token0.mint(address(this), 1e18);
    token1.mint(address(this), 8 * 1e9);

    squared.deposit(
      address(this),
      1 ether,
      abi.encode(
        PairMintCallbackData({
          token0: address(token0),
          token1: address(token1),
          amount0: 1e18,
          amount1: 8 * 1e9,
          payer: address(this)
        })
      )
    );

    token1.mint(cuh, 5 * 1e9);

    vm.prank(cuh);
    token1.approve(address(this), 5 * 1e9);
    squared.mint(cuh, 5 * 1e9, abi.encode(MintCallbackData({ token: address(token1), payer: cuh })));

    vm.warp(365 days + 1);

    squared.accrueInterest();

    uint256 borrowRate = squared.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year
    uint256 token1Dilution = squared.convertLiquidityToCollateral(lpDilution); // same as rewardPerPosition because
    // position size is 1

    assertEq(0.5 ether - lpDilution, squared.totalLiquidityBorrowed());
    assertEq(token1Dilution, squared.rewardPerPositionStored());
  }
}
