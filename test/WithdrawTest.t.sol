// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Squared } from "../src/core/Squared.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";
import { FullMath } from "../src/libraries/FullMath.sol";

contract WithdrawTest is TestHelper {
  event Withdraw(address indexed sender, uint256 size, uint256 liquidity, address indexed to);

  event Burn(uint256 amount0Out, uint256 amount1Out, uint256 liquidity, address indexed to);

  function setUp() external {
    _setUp();

    _deposit(cuh, cuh, 1 ether, 8 ether, 1 ether);
  }

  function testWithdrawPartial() external {
    (uint256 amount0, uint256 amount1, uint256 liquidity) = _withdraw(cuh, cuh, 0.5 ether);

    assertEq(liquidity, 0.5 ether);
    assertEq(0.5 ether, amount0);
    assertEq(4 ether, amount1);

    assertEq(0.5 ether, squared.totalLiquidity());
    assertEq(0.5 ether, squared.totalPositionSize());

    assertEq(0.5 ether, uint256(squared.reserve0()));
    assertEq(4 ether, uint256(squared.reserve1()));
    assertEq(0.5 ether, token0.balanceOf(address(squared)));
    assertEq(4 ether, token1.balanceOf(address(squared)));

    assertEq(0.5 ether, token0.balanceOf(address(cuh)));
    assertEq(4 ether, token1.balanceOf(address(cuh)));

    (uint256 positionSize,,) = squared.positions(cuh);
    assertEq(0.5 ether, positionSize);
  }

  function testWithdrawFull() external {
    (uint256 amount0, uint256 amount1, uint256 liquidity) = _withdraw(cuh, cuh, 1 ether);

    assertEq(liquidity, 1 ether);
    assertEq(1 ether, amount0);
    assertEq(8 ether, amount1);

    assertEq(0, squared.totalLiquidity());
    assertEq(0, squared.totalPositionSize());

    assertEq(0, uint256(squared.reserve0()));
    assertEq(0, uint256(squared.reserve1()));
    assertEq(0, token0.balanceOf(address(squared)));
    assertEq(0, token1.balanceOf(address(squared)));

    assertEq(1 ether, token0.balanceOf(address(cuh)));
    assertEq(8 ether, token1.balanceOf(address(cuh)));

    (uint256 positionSize,,) = squared.positions(cuh);
    assertEq(0, positionSize);
  }

  function testEmitsquared() external {
    vm.expectEmit(true, true, false, true, address(squared));
    emit Withdraw(cuh, 1 ether, 1 ether, cuh);
    _withdraw(cuh, cuh, 1 ether);
  }

  function testEmitPair() external {
    vm.expectEmit(true, false, false, true, address(squared));
    emit Burn(1 ether, 8 ether, 1 ether, cuh);
    _withdraw(cuh, cuh, 1 ether);
  }

  function testZeroWithdraw() external {
    vm.expectRevert(Squared.InputError.selector);
    _withdraw(cuh, cuh, 0);
  }

  function testOverWithdraw() external {
    vm.expectRevert(Squared.InsufficientPositionError.selector);
    _withdraw(cuh, cuh, 2 ether);
  }

  function testMaxUtilizedWithdraw() external {
    _mint(address(this), address(this), 5 ether);
    _withdraw(cuh, cuh, 0.5 ether);
  }

  function testCompleteUtilization() external {
    _mint(address(this), address(this), 5 ether);

    vm.expectRevert(Squared.CompleteUtilizationError.selector);
    _withdraw(cuh, cuh, 0.5 ether + 1);
  }

  function testAccrueOnWithdraw() external {
    _mint(address(this), address(this), 1 ether);
    vm.warp(365 days + 1);
    _withdraw(cuh, cuh, 0.5 ether);

    assertEq(365 days + 1, squared.lastUpdate());
    assert(squared.rewardPerPositionStored() != 0);
  }

  function testAccrueOnPositionWithdraw() external {
    _mint(address(this), address(this), 1 ether);
    vm.warp(365 days + 1);
    _withdraw(cuh, cuh, 0.5 ether);

    (, uint256 rewardPerPositionPaid, uint256 tokensOwed) = squared.positions(cuh);
    assert(rewardPerPositionPaid != 0);
    assert(tokensOwed != 0);
  }

  function testProportionalPositionSize() external {
    uint256 shares = _mint(address(this), address(this), 5 ether);
    vm.warp(365 days + 1);
    squared.accrueInterest();

    uint256 borrowRate = squared.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year

    uint256 reserve0 = squared.reserve0();
    uint256 reserve1 = squared.reserve1();

    uint256 _amount0 =
      FullMath.mulDivRoundingUp(reserve0, squared.convertShareToLiquidity(0.5 ether), squared.totalLiquidity());
    uint256 _amount1 =
      FullMath.mulDivRoundingUp(reserve1, squared.convertShareToLiquidity(0.5 ether), squared.totalLiquidity());

    _burn(address(this), address(this), 0.5 ether, _amount0, _amount1);

    (,, uint256 liquidity) = _withdraw(cuh, cuh, 1 ether);

    // check liquidity
    assertEq(liquidity, 1 ether - lpDilution);

    // check squared storage slots
    assertEq(squared.totalLiquidity(), 0);
    assertEq(squared.totalPositionSize(), 0);
    assertEq(squared.totalLiquidityBorrowed(), 0);
    assertEq(0, squared.reserve0());
    assertEq(0, squared.reserve1());
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

    (uint256 amount0, uint256 amount1, uint256 liquidity) = squared.withdraw(address(this), 0.5 ether);

    assertEq(liquidity, 0.5 ether);
    assertEq(0.5 ether, amount0);
    assertEq(4 * 1e9, amount1);

    assertEq(0.5 ether, squared.totalLiquidity());
    assertEq(0.5 ether, squared.totalPositionSize());

    assertEq(0.5 ether, uint256(squared.reserve0()));
    assertEq(4 * 1e9, uint256(squared.reserve1()));
    assertEq(0.5 ether, token0.balanceOf(address(squared)));
    assertEq(4 * 1e9, token1.balanceOf(address(squared)));

    assertEq(0.5 ether, token0.balanceOf(address(this)));
    assertEq(4 * 1e9, token1.balanceOf(address(this)));

    (uint256 positionSize,,) = squared.positions(address(this));
    assertEq(0.5 ether, positionSize);
  }
}
