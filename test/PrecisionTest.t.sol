// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "../src/core/Factory.sol";
import { Squared } from "../src/core/Squared.sol";
import { Pair } from "../src/core/Pair.sol";
import { TestHelper } from "./utils/TestHelper.sol";

// test for max tvl and min price of liquidity

// How much in usd terms does the minimum lp position cost
// How much in usd terms is the max tvl

// max asset value $1,000,000
// min asset value $0.000001
// max bound 10**9
// min bound 10**-9

// lp value precision: $1
// max tvl: $100,000,000

contract PrecisionTest is TestHelper {
  function setUp() external {
    _setUp();
  }

  function testBaseline() external {
    squared.invariant((upperBound * upperBound) / 1e18, 0, 1 ether);

    uint256 value = (upperBound * upperBound) / 1e18;
    uint256 basePerDollar = 1e18;

    uint256 minLP = value / basePerDollar;

    assert(type(uint120).max / basePerDollar >= 100_000_000);
    assert(minLP < 1 ether);
  }

  function testHighUpperBound() external {
    upperBound = 1e27;
    squared = Squared(factory.createSquared(address(token0), address(token1), token0Scale, token1Scale, upperBound));

    squared.invariant((upperBound * upperBound) / 1e18, 0, 1 ether);

    uint256 value = (upperBound * upperBound) / 1e18;
    uint256 basePerDollar = 1e21;

    uint256 minLP = value / basePerDollar;

    assert(type(uint120).max / basePerDollar >= 100_000_000);
    assert(minLP < 1 ether);
  }

  function testLowUpperBound() external {
    upperBound = 1e9;
    squared = Squared(factory.createSquared(address(token0), address(token1), token0Scale, token1Scale, upperBound));

    squared.invariant((upperBound * upperBound) / 1e18, 0, 1 ether);

    uint256 value = (upperBound * upperBound) / 1e18;
    uint256 basePerDollar = 1e27;

    uint256 minLP = value / basePerDollar;

    assert(type(uint120).max / basePerDollar >= 100_000_000);
    assert(minLP < 1 ether);
  }
}
