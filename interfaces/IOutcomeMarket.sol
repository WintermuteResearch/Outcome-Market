// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IOutcomeMarket {

    /// @notice Takes USDC and mints both KAMALA and HARRIS for each unit
    /// @param usdcAmount The USDC amount for conversion to conditional tokens
    function mint(uint256 usdcAmount) external;

    /// @notice Burns conditional tokens and returns USDC according to the market outcome
    function redeem() external;

    /// @notice Resolves the market if the oracle provided value
    function resolve() external;


}