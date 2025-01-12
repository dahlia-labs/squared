// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Squared } from "../src/core/Squared.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";

contract MintTest is TestHelper {
  event Mint(address indexed sender, uint256 collateral, uint256 shares, uint256 liquidity, address indexed to);

  event Burn(uint256 amount0Out, uint256 amount1Out, uint256 liquidity, address indexed to);

  function setUp() external {
    _setUp();
    _deposit(address(this), address(this), 1 ether, 8 ether, 1 ether);
  }

  function testMintPartial() external {
    uint256 shares = _mint(cuh, cuh, 5 ether);

    // check squared token
    assertEq(0.5 ether, shares);
    assertEq(0.5 ether, squared.totalSupply());
    assertEq(0.5 ether, squared.balanceOf(cuh));

    // check squared storage slots
    assertEq(0.5 ether, squared.totalLiquidityBorrowed());
    assertEq(0.5 ether, squared.totalLiquidity());
    assertEq(0.5 ether, uint256(squared.reserve0()));
    assertEq(4 ether, uint256(squared.reserve1()));

    // check squared balances
    assertEq(0.5 ether, token0.balanceOf(address(squared)));
    assertEq(4 ether + 5 ether, token1.balanceOf(address(squared)));

    // check user balances
    assertEq(0.5 ether, token0.balanceOf(cuh));
    assertEq(4 ether, token1.balanceOf(cuh));
  }

  function testMintFull() external {
    uint256 shares = _mint(cuh, cuh, 10 ether);

    // check squared token
    assertEq(1 ether, shares);
    assertEq(1 ether, squared.totalSupply());
    assertEq(1 ether, squared.balanceOf(cuh));

    // check squared storage slots
    assertEq(1 ether, squared.totalLiquidityBorrowed());
    assertEq(0, squared.totalLiquidity());
    assertEq(0, uint256(squared.reserve0()));
    assertEq(0, uint256(squared.reserve1()));

    // check squared balances
    assertEq(0, token0.balanceOf(address(squared)));
    assertEq(10 ether, token1.balanceOf(address(squared)));

    // check user balances
    assertEq(1 ether, token0.balanceOf(cuh));
    assertEq(8 ether, token1.balanceOf(cuh));
  }

  function testMintFullDouble() external {
    _mint(cuh, cuh, 5 ether);
    _mint(cuh, cuh, 5 ether);
  }

  function testZeroMint() external {
    vm.expectRevert(Squared.InputError.selector);
    squared.mint(cuh, 0, bytes(""));
  }

  function testOverMint() external {
    _mint(address(this), address(this), 5 ether);

    vm.expectRevert(Squared.CompleteUtilizationError.selector);
    squared.mint(cuh, 5 ether + 10, bytes(""));
  }

  function testEmitsquared() external {
    token1.mint(cuh, 5 ether);

    vm.prank(cuh);
    token1.approve(address(this), 5 ether);

    vm.expectEmit(true, true, false, true, address(squared));
    emit Mint(address(this), 5 ether, 0.5 ether, 0.5 ether, cuh);
    squared.mint(cuh, 5 ether, abi.encode(MintCallbackData({ token: address(token1), payer: cuh })));
  }

  function testEmitPair() external {
    token1.mint(cuh, 5 ether);

    vm.prank(cuh);
    token1.approve(address(this), 5 ether);

    vm.expectEmit(true, false, false, true, address(squared));
    emit Burn(0.5 ether, 4 ether, 0.5 ether, cuh);
    squared.mint(cuh, 5 ether, abi.encode(MintCallbackData({ token: address(token1), payer: cuh })));
  }

  function testAccrueOnMint() external {
    _mint(cuh, cuh, 1 ether);
    vm.warp(365 days + 1);
    _mint(cuh, cuh, 1 ether);

    assertEq(365 days + 1, squared.lastUpdate());
    assert(squared.rewardPerPositionStored() != 0);
  }

  function testProportionalMint() external {
    _mint(cuh, cuh, 5 ether);
    vm.warp(365 days + 1);
    uint256 shares = _mint(cuh, cuh, 1 ether);

    uint256 borrowRate = squared.getBorrowRate(0.5 ether, 1 ether);
    uint256 lpDilution = borrowRate / 2; // 0.5 lp for one year

    // check mint amount
    assertEq((0.1 ether * 0.5 ether) / (0.5 ether - lpDilution), shares);
    assertEq(shares + 0.5 ether, squared.balanceOf(cuh));

    // check squared storage slots
    assertEq(0.6 ether - lpDilution, squared.totalLiquidityBorrowed());
    assertEq(shares + 0.5 ether, squared.totalSupply());
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
    uint256 shares = squared.mint(cuh, 5 * 1e9, abi.encode(MintCallbackData({ token: address(token1), payer: cuh })));

    // check squared token
    assertEq(0.5 ether, shares);
    assertEq(0.5 ether, squared.totalSupply());
    assertEq(0.5 ether, squared.balanceOf(cuh));

    // check squared storage slots
    assertEq(0.5 ether, squared.totalLiquidityBorrowed());
    assertEq(0.5 ether, squared.totalLiquidity());
    assertEq(0.5 ether, uint256(squared.reserve0()));
    assertEq(4 * 1e9, uint256(squared.reserve1()));

    // check squared balances
    assertEq(0.5 ether, token0.balanceOf(address(squared)));
    assertEq(9 * 1e9, token1.balanceOf(address(squared)));

    // check user balances
    assertEq(0.5 ether, token0.balanceOf(cuh));
    assertEq(4 * 1e9, token1.balanceOf(cuh));
  }

  function testMintAfterFullAccrue() external {
    _mint(address(this), address(this), 5 ether);
    vm.warp(730 days + 1);

    vm.expectRevert(Squared.CompleteUtilizationError.selector);
    squared.mint(cuh, 1 ether, bytes(""));
  }
}
