// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ElectionResult} from "../interfaces/IElectionOracle.sol";

/// @title OutcomeERC20
/// @notice Outcome ERC20 token
contract OutcomeERC20 is ERC20 {
    /// @notice The address of the contract responsible for minting and burning tokens
    address public immutable outcomeMarket;

    /// @notice The type of market outcome this token represents
    ElectionResult public immutable marketOutcomeType;

    /// @notice Emitted when the token contract is deployed
    /// @param outcome The market outcome type this token represents
    /// @param outcomeMarket The address of the market contract responsible for minting and burning
    event OutcomeERC20Deployed(ElectionResult indexed outcome, address indexed outcomeMarket);

    /// @notice Thrown when a non-market tries to mint or burn tokens
    error OutcomeERC20__SenderNotOutcomeMarket();

    // @notice This will revert if the caller is not the market
    modifier onlyMarket() {
        if (msg.sender != outcomeMarket) {
            revert OutcomeERC20__SenderNotOutcomeMarket();
        }
        _;
    }

    /// @notice Initializes the outcome ERC20 token
    /// @param _name The name of the ERC20 token
    /// @param _symbol The symbol of the ERC20 token
    /// @param _outcomeType The market outcome this token represents
    constructor(string memory _name, string memory _symbol, ElectionResult _outcomeType) ERC20(_name, _symbol) {
        outcomeMarket = msg.sender;
        marketOutcomeType = _outcomeType;
        emit OutcomeERC20Deployed(_outcomeType, msg.sender);
    }

    /// @notice Mints outcome ERC20 tokens
    /// @dev Can only be called by the designated market contract
    /// @param _account The address that will receive the minted tokens
    /// @param _amount The amount of tokens to be minted
    function mint(address _account, uint256 _amount) external onlyMarket {
        _mint(_account, _amount);
    }

    /// @notice Burns outcome ERC20 tokens
    /// @dev Can only be called by the designated market contract
    /// @param _account The address from which tokens will be burned
    /// @param _amount The amount of tokens to be burned
    function burn(address _account, uint256 _amount) external onlyMarket {
        _burn(_account, _amount);
    }
}
