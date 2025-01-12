// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Multicall } from "./Multicall.sol";
import { Payment } from "./Payment.sol";
import { SelfPermit } from "./SelfPermit.sol";

import { ISquared } from "../core/interfaces/ISquared.sol";
import { IPairMintCallback } from "../core/interfaces/callback/IPairMintCallback.sol";

import { FullMath } from "../libraries/FullMath.sol";
import { SquaredAddress } from "./libraries/SquaredAddress.sol";

/// @notice Manages liquidity provider positions
/// @author Kyle Scott and Robert Leifke
contract LiquidityManager is Multicall, Payment, SelfPermit, IPairMintCallback {
  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
  event AddLiquidity(
    address indexed from,
    address indexed squared,
    uint256 liquidity,
    uint256 size,
    uint256 amount0,
    uint256 amount1,
    address indexed to
  );

  event RemoveLiquidity(
    address indexed from,
    address indexed squared,
    uint256 liquidity,
    uint256 size,
    uint256 amount0,
    uint256 amount1,
    address indexed to
  );

  event Collect(address indexed from, address indexed squared, uint256 amount, address indexed to);

  /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

  error LivelinessError();

  error AmountError();

  error ValidationError();

  error PositionInvalidError();

  error CollectError();

  /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

  address public immutable factory;

  struct Position {
    uint256 size;
    uint256 rewardPerPositionPaid;
    uint256 tokensOwed;
  }

  /// @notice Owner to squared to position
  mapping(address => mapping(address => Position)) public positions;

  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor(address _factory, address _weth) Payment(_weth) {
    factory = _factory;
  }

  /*//////////////////////////////////////////////////////////////
                           LIVELINESS MODIFIER
    //////////////////////////////////////////////////////////////*/

  modifier checkDeadline(uint256 deadline) {
    if (deadline < block.timestamp) revert LivelinessError();
    _;
  }

  /*//////////////////////////////////////////////////////////////
                                CALLBACK
    //////////////////////////////////////////////////////////////*/

  struct PairMintCallbackData {
    address token0;
    address token1;
    uint256 token0Exp;
    uint256 token1Exp;
    uint256 upperBound;
    uint256 amount0;
    uint256 amount1;
    address payer;
  }

  /// @notice callback that sends the underlying tokens for the specified amount of liquidity shares
  function pairMintCallback(uint256, bytes calldata data) external {
    PairMintCallbackData memory decoded = abi.decode(data, (PairMintCallbackData));

    address squared = SquaredAddress.computeAddress(
      factory, decoded.token0, decoded.token1, decoded.token0Exp, decoded.token1Exp, decoded.upperBound
    );
    if (squared != msg.sender) revert ValidationError();

    if (decoded.amount0 > 0) pay(decoded.token0, decoded.payer, msg.sender, decoded.amount0);
    if (decoded.amount1 > 0) pay(decoded.token1, decoded.payer, msg.sender, decoded.amount1);
  }

  /*//////////////////////////////////////////////////////////////
                        LIQUIDITY MANAGER LOGIC
    //////////////////////////////////////////////////////////////*/

  struct AddLiquidityParams {
    address token0;
    address token1;
    uint256 token0Exp;
    uint256 token1Exp;
    uint256 upperBound;
    uint256 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 sizeMin;
    address recipient;
    uint256 deadline;
  }

  /// @notice Add liquidity to a liquidity position
  function addLiquidity(AddLiquidityParams calldata params) external payable checkDeadline(params.deadline) {
    address squared = SquaredAddress.computeAddress(
      factory, params.token0, params.token1, params.token0Exp, params.token1Exp, params.upperBound
    );

    uint256 r0 = ISquared(squared).reserve0();
    uint256 r1 = ISquared(squared).reserve1();
    uint256 totalLiquidity = ISquared(squared).totalLiquidity();

    uint256 amount0;
    uint256 amount1;

    if (totalLiquidity == 0) {
      amount0 = params.amount0Min;
      amount1 = params.amount1Min;
    } else {
      amount0 = FullMath.mulDivRoundingUp(params.liquidity, r0, totalLiquidity);
      amount1 = FullMath.mulDivRoundingUp(params.liquidity, r1, totalLiquidity);
    }

    if (amount0 < params.amount0Min || amount1 < params.amount1Min) revert AmountError();

    uint256 size = ISquared(squared).deposit(
      address(this),
      params.liquidity,
      abi.encode(
        PairMintCallbackData({
          token0: params.token0,
          token1: params.token1,
          token0Exp: params.token0Exp,
          token1Exp: params.token1Exp,
          upperBound: params.upperBound,
          amount0: amount0,
          amount1: amount1,
          payer: msg.sender
        })
      )
    );
    if (size < params.sizeMin) revert AmountError();

    Position memory position = positions[params.recipient][squared]; // SLOAD

    (, uint256 rewardPerPositionPaid,) = ISquared(squared).positions(address(this));
    position.tokensOwed += FullMath.mulDiv(position.size, rewardPerPositionPaid - position.rewardPerPositionPaid, 1e18);
    position.rewardPerPositionPaid = rewardPerPositionPaid;
    position.size += size;

    positions[params.recipient][squared] = position; // SSTORE

    emit AddLiquidity(msg.sender, squared, params.liquidity, size, amount0, amount1, params.recipient);
  }

  struct RemoveLiquidityParams {
    address token0;
    address token1;
    uint256 token0Exp;
    uint256 token1Exp;
    uint256 upperBound;
    uint256 size;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
    uint256 deadline;
  }

  /// @notice Removes from a liquidity position
  function removeLiquidity(RemoveLiquidityParams calldata params) external payable checkDeadline(params.deadline) {
    address squared = SquaredAddress.computeAddress(
      factory, params.token0, params.token1, params.token0Exp, params.token1Exp, params.upperBound
    );

    address recipient = params.recipient == address(0) ? address(this) : params.recipient;

    (uint256 amount0, uint256 amount1, uint256 liquidity) = ISquared(squared).withdraw(recipient, params.size);
    if (amount0 < params.amount0Min || amount1 < params.amount1Min) revert AmountError();

    Position memory position = positions[msg.sender][squared]; // SLOAD

    (, uint256 rewardPerPositionPaid,) = ISquared(squared).positions(address(this));
    position.tokensOwed += FullMath.mulDiv(position.size, rewardPerPositionPaid - position.rewardPerPositionPaid, 1e18);
    position.rewardPerPositionPaid = rewardPerPositionPaid;
    position.size -= params.size;

    positions[msg.sender][squared] = position; // SSTORE

    emit RemoveLiquidity(msg.sender, squared, liquidity, params.size, amount0, amount1, recipient);
  }

  struct CollectParams {
    address squared;
    address recipient;
    uint256 amountRequested;
  }

  /// @notice Collects interest owed to the callers liqudity position
  function collect(CollectParams calldata params) external payable returns (uint256 amount) {
    ISquared(params.squared).accruePositionInterest();

    address recipient = params.recipient == address(0) ? address(this) : params.recipient;

    Position memory position = positions[msg.sender][params.squared]; // SLOAD

    (, uint256 rewardPerPositionPaid,) = ISquared(params.squared).positions(address(this));
    position.tokensOwed += FullMath.mulDiv(position.size, rewardPerPositionPaid - position.rewardPerPositionPaid, 1e18);
    position.rewardPerPositionPaid = rewardPerPositionPaid;

    amount = params.amountRequested > position.tokensOwed ? position.tokensOwed : params.amountRequested;
    position.tokensOwed -= amount;

    positions[msg.sender][params.squared] = position; // SSTORE

    uint256 collectAmount = ISquared(params.squared).collect(recipient, amount);
    if (collectAmount != amount) revert CollectError(); // extra check for safety

    emit Collect(msg.sender, params.squared, amount, recipient);
  }
}
