// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IElectionOracle.sol";

contract ElectionOracle is AccessControl {
    ElectionResult public result;
    bool public isResultFinalized;
    address public owner;
    address public pendingOwner;
    uint256 public immutable minEndOfElectionTimestamp;
    uint256 public resultFinalizationTimestamp;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferCanceled(address indexed currentOwner, address indexed pendingOwner);
    event OwnershipTransferInitiated(address indexed previousOwner, address indexed newOwner);
    event ElectionFinalized(ElectionResult indexed finalResult, uint256 indexed timestamp);

    /**
     * @dev Constructor to initialize the contract.
     * @param _owner The address being set as the owner of the contract.
     * @param oracle The address being assigned the ORACLE_ROLE to finalize the election result.
     * @param _minEndOfElectionTimestamp The minimum timestamp marking the end of the election period before it can be finalized.
     */
    constructor(address _owner, address oracle, uint256 _minEndOfElectionTimestamp) {
        require(_owner != address(0), "Owner address cannot be the zero address");
        owner = _owner;

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ORACLE_ROLE, oracle);

        require(_minEndOfElectionTimestamp > block.timestamp, "minEndOfElectionTimestamp must be in the future.");
        minEndOfElectionTimestamp = _minEndOfElectionTimestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // ==================== ELECTION FUNCTIONS ====================

    function finalizeElectionResult(ElectionResult _finalResult) external onlyRole(ORACLE_ROLE) {
        require(block.timestamp >= minEndOfElectionTimestamp, "Cannot finalize before the end of the election period.");
        require(result == ElectionResult.NotSet, "Election result is already finalized.");
        require(_finalResult != ElectionResult.NotSet, "Invalid election result is provided.");

        result = _finalResult;
        isResultFinalized = true;
        resultFinalizationTimestamp = block.timestamp;

        emit ElectionFinalized(_finalResult, block.timestamp);
    }

    function getElectionResult() external view returns (ElectionResult) {
        require(isResultFinalized, "Election has not been finalized yet");
        return result;
    }

    function isElectionFinalized() external view returns (bool) {
        return isResultFinalized;
    }

    // ==================== OWNERSHIP FUNCTIONS ====================

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner address cannot be the zero address");
        require(newOwner != owner, "New owner address cannot be the current owner address");

        pendingOwner = newOwner;
        emit OwnershipTransferInitiated(owner, newOwner);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Only pending owner can accept ownership");

        _grantRole(DEFAULT_ADMIN_ROLE, pendingOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, owner);

        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    function cancelOwnershipTransfer() external onlyOwner {
        require(pendingOwner != address(0), "No pending ownership transfer to cancel");
        address canceledPendingOwner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferCanceled(owner, canceledPendingOwner);
    }

    // ==================== ORACLE MANAGEMENT FUNCTIONS ====================

    function grantOracleRole(address account) external onlyOwner {
        _grantRole(ORACLE_ROLE, account);
    }

    function revokeOracleRole(address account) external onlyOwner {
        _revokeRole(ORACLE_ROLE, account);
    }
}
