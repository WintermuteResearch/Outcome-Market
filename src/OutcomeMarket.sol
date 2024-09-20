// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OutcomeERC20} from "./OutcomeERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IElectionOracle, ElectionResult} from "../interfaces/IElectionOracle.sol";
import {IOutcomeMarket} from "../interfaces/IOutcomeMarket.sol";

/// @title OutcomeMarket
/// @notice The manager contract for the outcome market
contract OutcomeMarket is IOutcomeMarket {
    /// @notice Address representing the case where neither Trump nor Harris won
    address public constant OTHER_WINNER = address(0xdEaD);

    /// @notice The difference between decimals of outcome tokens and USDC
    uint256 public constant COLLATERAL_TOKEN_DECIMAL_DIFF = 1e12;

    /// @notice The ERC20 token used as collateral for this market
    IERC20 public immutable collateralToken;

    /// @notice Oracle that provides the relevant result
    IElectionOracle public immutable oracle;

    /// @notice Array of outcome tokens representing different outcomes
    OutcomeERC20[2] public outcomeTokens;

    /// @notice The outcome token representing the winning outcome
    OutcomeERC20 public winningOutcomeToken;

    /// @notice Emitted when the market is resolved and a winning token is identified
    /// @param winningToken The address of the winning outcome token
    event MarketResolved(address indexed winningToken);

    /// @notice Emitted when a payout is distributed to a user
    /// @param receiver The address of the user receiving the payout
    /// @param amount The amount of collateral distributed
    event PayoutDistributed(address indexed receiver, uint256 indexed amount);

    /// @notice Emitted when a user creates a new positions
    /// @param user The address of the user minting tokens
    /// @param collateralAmount The amount of collateral token used for minting
    event PositionCreated(address indexed user, uint256 indexed collateralAmount);

    /// @notice Thrown when the market has not yet been resolved
    error OutcomeMarket__MarketNotResolved();

    /// @notice Thrown when the market has already been resolved
    error OutcomeMarket__MarketResolved();

    /// @notice Thrown when the oracle returns an unknown market result
    error OutcomeMarket__UnknownOracleResult();

    /// @notice Thrown when the user can't redeem anything
    error OutcomeMarket__NothingToRedeem();

    /// @notice This will revert if the market was not resolved
    modifier onlyAfterResolution() {
        if (address(winningOutcomeToken) == address(0)) {
            revert OutcomeMarket__MarketNotResolved();
        }
        _;
    }

    /// @notice This will revert if the market was resolved
    modifier onlyBeforeResolution() {
        if (address(winningOutcomeToken) != address(0)) {
            revert OutcomeMarket__MarketResolved();
        }
        _;
    }

    /// @notice Initializes the manager contract
    /// @param _collateral The ERC20 token used as collateral for this market
    /// @param _oracle The oracle contract that provides market results
    constructor(IERC20 _collateral, IElectionOracle _oracle) {
        outcomeTokens[0] = new OutcomeERC20("Trump", "TRUMP", ElectionResult.Trump);
        outcomeTokens[1] = new OutcomeERC20("Harris", "HARRIS", ElectionResult.Harris);
        collateralToken = _collateral;
        oracle = _oracle;
    }

    /// @inheritdoc IOutcomeMarket
    function mint(uint256 collateralAmount) external onlyBeforeResolution {
        collateralToken.transferFrom(msg.sender, address(this), collateralAmount);
        uint256 normalizedMintingAmount = collateralAmount * COLLATERAL_TOKEN_DECIMAL_DIFF;
        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            outcomeTokens[i].mint(msg.sender, normalizedMintingAmount);
        }
        emit PositionCreated(msg.sender, collateralAmount);
    }

    /// @inheritdoc IOutcomeMarket
    function redeem() external onlyAfterResolution {
        if (address(winningOutcomeToken) == OTHER_WINNER) {
            _handleRedeemCaseOther();
            return;
        }

        uint256 winningTokenBalance = winningOutcomeToken.balanceOf(msg.sender);

        if (winningTokenBalance == 0) {
            return;
        }
        uint256 collateralAmount = _calcCollateralShare(winningTokenBalance, winningOutcomeToken.totalSupply());

        winningOutcomeToken.burn(msg.sender, winningTokenBalance);
        collateralToken.transfer(msg.sender, collateralAmount);

        emit PayoutDistributed(msg.sender, collateralAmount);
    }

    /// @inheritdoc IOutcomeMarket
    function resolve() external onlyBeforeResolution {
        if (!oracle.isElectionFinalized()) {
            revert OutcomeMarket__MarketNotResolved();
        }

        winningOutcomeToken = _handleOracleAnswer(oracle.getElectionResult());
        emit MarketResolved(address(winningOutcomeToken));
    }

    /// @notice Handles the resolution of the market based on the oracle's response
    /// @param result The result provided by the oracle
    /// @return winningToken The winning outcome token corresponding to the market result
    function _handleOracleAnswer(ElectionResult result) internal view returns (OutcomeERC20 winningToken) {
        if (result == ElectionResult.Other) {
            // Collateral is split 50/50 amongst Trump/Harris
            return OutcomeERC20(OTHER_WINNER);
        }

        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            if (outcomeTokens[i].marketOutcomeType() == result) {
                return outcomeTokens[i];
            }
        }
        revert OutcomeMarket__UnknownOracleResult();
    }

    /// @notice Handles redemption when neither Trump nor Harris won
    /// @dev Exchange rate in this case is 1 outcome token -> 0.5 collateral token
    function _handleRedeemCaseOther() internal {
        uint256 _totalBalance;
        uint256 _outcomeTokensTotalSupply = outcomeTokens[0].totalSupply() + outcomeTokens[1].totalSupply();
        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            OutcomeERC20 _outcomeToken = outcomeTokens[i];
            uint256 _senderBalance = _outcomeToken.balanceOf(msg.sender);
            if (_senderBalance > 0) {
                _outcomeToken.burn(msg.sender, _senderBalance);
                _totalBalance += _senderBalance;
            }
        }
        uint256 _totalCollateral = _calcCollateralShare(_totalBalance, _outcomeTokensTotalSupply);
        if (_totalCollateral != 0) {
            collateralToken.transfer(msg.sender, _totalCollateral);
            emit PayoutDistributed(msg.sender, _totalCollateral);
        } else {
            revert OutcomeMarket__NothingToRedeem();
        }
    }

    /// @notice Calculates the collateral share based on token holdings and total supply
    /// @dev In the case where "other" is the outcome, winningTokenSupply
    /// is the sum of supplies for both outcome tokens since in this case, the conversion
    /// rate is 1 outcome token -> 0.5 collateral token.
    /// @param winningTokenAmount The amount of winning tokens held by the user
    /// @param winningTokenSupply The total supply of the winning token
    /// @return _share The share of collateral tokens corresponding to the user's winning tokens
    function _calcCollateralShare(uint256 winningTokenAmount, uint256 winningTokenSupply)
        internal
        view
        returns (uint256 _share)
    {
        uint256 availableCollateral = collateralToken.balanceOf(address(this));
        _share = Math.mulDiv(winningTokenAmount, availableCollateral, winningTokenSupply);
    }
}
