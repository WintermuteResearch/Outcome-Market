// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ElectionOracle.sol";

contract ElectionOracleTest is Test {
    ElectionOracle public electionOracle;
    address public owner = address(0xABCD);
    address public oracle = address(0x1234);
    address public newOwner = address(0x1111);
    uint256 public minEndOfElectionTimestamp;

    function setUp() public {
        // Set the minimum end of election timestamp to 1 day from now
        minEndOfElectionTimestamp = block.timestamp + 1 days;

        // Deploy the contract with the specified owner, oracle, and timestamp
        electionOracle = new ElectionOracle(owner, oracle, minEndOfElectionTimestamp);
    }

    function testInitialOwnership() public view {
        // Verify that the owner is correctly set as specified during deployment
        assertEq(electionOracle.owner(), owner);
    }

    function testOnlyOwnerCanGrantOracleRole() public {
        vm.startPrank(newOwner);

        vm.expectRevert("Only owner can call this function");
        electionOracle.grantOracleRole(address(0x9999));

        vm.stopPrank();
    }

    function testOwnerCanGrantAndRevokeOracleRole() public {
        vm.startPrank(owner);

        electionOracle.grantOracleRole(address(0x9999));
        assertTrue(electionOracle.hasRole(electionOracle.ORACLE_ROLE(), address(0x9999)));

        electionOracle.revokeOracleRole(address(0x9999));
        assertFalse(electionOracle.hasRole(electionOracle.ORACLE_ROLE(), address(0x9999)));

        vm.stopPrank();
    }

    function testOwnershipTransfer() public {
        vm.startPrank(owner);

        electionOracle.transferOwnership(newOwner);

        assertTrue(electionOracle.hasRole(electionOracle.DEFAULT_ADMIN_ROLE(), newOwner));
        assertEq(electionOracle.owner(), newOwner);

        vm.stopPrank();
    }

    function testCannotTransferOwnershipToZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert("New owner address cannot be the zero address");
        electionOracle.transferOwnership(address(0));

        vm.stopPrank();
    }

    function testOracleCanFinalizeElectionResult() public {
        vm.startPrank(oracle);

        vm.warp(minEndOfElectionTimestamp + 1);

        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.Trump);

        assertTrue(electionOracle.isElectionFinalized());
        assertEq(uint8(electionOracle.result()), uint8(ElectionOracle.ElectionResult.Trump));

        vm.stopPrank();
    }

    function testCannotFinalizeTwice() public {
        vm.startPrank(oracle);
        vm.warp(minEndOfElectionTimestamp + 1);

        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.Harris);

        vm.expectRevert("Election result is already finalized.");
        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.Trump);

        vm.stopPrank();
    }

    function testUnauthorizedCannotGrantOrRevokeRoles() public {
        address unauthorized = address(0x5678);

        vm.startPrank(unauthorized);

        vm.expectRevert("Only owner can call this function");
        electionOracle.grantOracleRole(address(0x1111));

        vm.expectRevert("Only owner can call this function");
        electionOracle.revokeOracleRole(oracle);

        vm.stopPrank();
    }

    function testOldOwnerCannotGrantOrRevokeAfterOwnershipTransfer() public {
        vm.startPrank(owner);

        electionOracle.transferOwnership(newOwner);
        vm.expectRevert("Only owner can call this function");
        electionOracle.grantOracleRole(address(0x9999));

        vm.expectRevert("Only owner can call this function");
        electionOracle.revokeOracleRole(oracle);

        vm.stopPrank();
    }

    function testGetElectionResultBeforeFinalization() public {
        vm.expectRevert("Election has not been finalized yet");
        electionOracle.getElectionResult();
    }

    function testGetElectionResultAfterFinalization() public {
        vm.startPrank(oracle);
        vm.warp(minEndOfElectionTimestamp + 1);

        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.Trump);

        assertEq(uint8(electionOracle.getElectionResult()), uint8(ElectionOracle.ElectionResult.Trump));

        vm.stopPrank();
    }

    function testCannotFinalizeBeforeMinimumTime() public {
        vm.startPrank(oracle);

        vm.warp(minEndOfElectionTimestamp - 1);
        vm.expectRevert("Cannot finalize before the end of the election period.");
        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.Trump);

        vm.stopPrank();
    }
}
