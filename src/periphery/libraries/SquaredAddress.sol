// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

import { Squared } from "../../core/Squared.sol";

/// @notice Library for computing the address of a Squared using only its inputs
library SquaredAddress {

  function computeAddress(
    address factory,
    address token0,
    address token1,
    uint256 token0Exp,
    uint256 token1Exp,
    uint256 upperBound
  )
    internal
    pure
    returns (address squared)
  {
    squared = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(
              hex"ff",
              factory,
              keccak256(abi.encode(token0, token1, token0Exp, token1Exp, upperBound)),
              keccak256(type(Squared).creationCode)
            )
          )
        )
      )
    );
  }
}
