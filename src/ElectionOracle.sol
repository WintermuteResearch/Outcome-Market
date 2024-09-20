// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract ElectionOracle is AccessControl {
    enum ElectionResult {
        NotSet,
        Trump,
        Harris,
        Other
    }

    ElectionResult public result;
    bool public isResultFinalized;
    address public owner;
    uint256 public minEndOfElectionTimestamp;
    uint256 public resultFinalizationTimestamp;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
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

        result = ElectionResult.NotSet;
        isResultFinalized = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

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

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner address cannot be the zero address");

        grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        revokeRole(DEFAULT_ADMIN_ROLE, owner);

        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function grantOracleRole(address account) external onlyOwner {
        grantRole(ORACLE_ROLE, account);
    }

    function revokeOracleRole(address account) external onlyOwner {
        revokeRole(ORACLE_ROLE, account);
    }
}
