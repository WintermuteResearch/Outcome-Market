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

    // ====================
    // OWNERSHIP TESTS
    // ====================

    function testOwnershipTransfer() public {
        vm.startPrank(owner);

        electionOracle.transferOwnership(newOwner);
        assertEq(electionOracle.pendingOwner(), newOwner);
        assertEq(electionOracle.owner(), owner); // Owner hasn't changed yet

        vm.stopPrank();

        vm.prank(newOwner);
        electionOracle.acceptOwnership();

        assertEq(electionOracle.owner(), newOwner);
        assertEq(electionOracle.pendingOwner(), address(0));
        assertTrue(electionOracle.hasRole(electionOracle.DEFAULT_ADMIN_ROLE(), newOwner));
        assertFalse(electionOracle.hasRole(electionOracle.DEFAULT_ADMIN_ROLE(), owner));

        vm.stopPrank();
    }

    function testOwnerCanChangeTransferWhilePending() public {
        vm.startPrank(owner);

        // Initiate ownership transfer to newOwner
        electionOracle.transferOwnership(newOwner);
        assertEq(electionOracle.pendingOwner(), newOwner);

        // Change pending transfer to a different address
        address anotherNewOwner = address(0x2222);
        electionOracle.transferOwnership(anotherNewOwner);
        assertEq(electionOracle.pendingOwner(), anotherNewOwner);

        // Ensure the original newOwner can't accept ownership
        vm.stopPrank();
        vm.prank(newOwner);
        vm.expectRevert("Only pending owner can accept ownership");
        electionOracle.acceptOwnership();

        // Ensure the new pending owner can accept ownership
        vm.prank(anotherNewOwner);
        electionOracle.acceptOwnership();

        assertEq(electionOracle.owner(), anotherNewOwner);
        assertEq(electionOracle.pendingOwner(), address(0));
        assertTrue(electionOracle.hasRole(electionOracle.DEFAULT_ADMIN_ROLE(), anotherNewOwner));
        assertFalse(electionOracle.hasRole(electionOracle.DEFAULT_ADMIN_ROLE(), owner));

        vm.stopPrank();
    }

    function testCancelOwnershipTransfer() public {
        vm.startPrank(owner);

        // Initiate ownership transfer
        electionOracle.transferOwnership(newOwner);
        assertEq(electionOracle.pendingOwner(), newOwner);

        // Cancel ownership transfer
        electionOracle.cancelOwnershipTransfer();
        assertEq(electionOracle.pendingOwner(), address(0));
        assertEq(electionOracle.owner(), owner);

        // Ensure newOwner can't accept ownership after cancellation
        vm.stopPrank();
        vm.prank(newOwner);
        vm.expectRevert("Only pending owner can accept ownership");
        electionOracle.acceptOwnership();

        vm.stopPrank();
    }

    function testCannotTransferOwnershipToZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert("New owner address cannot be the zero address");
        electionOracle.transferOwnership(address(0));

        vm.stopPrank();
    }

    function testCannotAcceptOwnershipIfNotPendingOwner() public {
        vm.prank(owner);
        electionOracle.transferOwnership(newOwner);

        vm.prank(address(0x9999));
        vm.expectRevert("Only pending owner can accept ownership");
        electionOracle.acceptOwnership();
    }

    function testCannotTransferOwnershipToCurrentOwner() public {
        vm.prank(owner);
        vm.expectRevert("New owner address cannot be the current owner address");
        electionOracle.transferOwnership(owner);
    }

    function testOldOwnerCannotGrantOrRevokeAfterOwnershipTransfer() public {
        vm.prank(owner);
        electionOracle.transferOwnership(newOwner);

        vm.prank(newOwner);
        electionOracle.acceptOwnership();

        vm.startPrank(owner);
        vm.expectRevert("Only owner can call this function");
        electionOracle.grantOracleRole(address(0x9999));

        vm.expectRevert("Only owner can call this function");
        electionOracle.revokeOracleRole(oracle);
        vm.stopPrank();
    }

    // ====================
    // ORACLE ROLE TESTS
    // ====================

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

    function testUnauthorizedCannotGrantOrRevokeRoles() public {
        address unauthorized = address(0x5678);

        vm.startPrank(unauthorized);

        vm.expectRevert("Only owner can call this function");
        electionOracle.grantOracleRole(address(0x1111));

        vm.expectRevert("Only owner can call this function");
        electionOracle.revokeOracleRole(oracle);

        vm.stopPrank();
    }

    function testInitialOracleRole() public view {
        assertTrue(electionOracle.hasRole(electionOracle.ORACLE_ROLE(), oracle));
    }

    // ====================
    // ELECTION FINALIZATION TESTS
    // ====================

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

    function testCannotFinalizeWithNotSetResult() public {
        vm.startPrank(oracle);
        vm.warp(minEndOfElectionTimestamp + 1);
        vm.expectRevert("Invalid election result is provided.");
        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.NotSet);
        vm.stopPrank();
    }

    function testGetElectionResultBeforeFinalization() public {
        vm.expectRevert("Election has not been finalized yet");
        electionOracle.getElectionResult();
    }

    function testNonOracleCannotFinalizeElection() public {
        vm.warp(minEndOfElectionTimestamp + 1);
        vm.prank(address(0x9999));
        vm.expectRevert();
        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.Trump);
    }

    function testOwnerCannotFinalizeElection() public {
        vm.warp(minEndOfElectionTimestamp + 1);
        vm.prank(owner);
        vm.expectRevert();
        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.Trump);
    }

    function testRevokedOracleCannotFinalizeElection() public {
        vm.prank(owner);
        electionOracle.revokeOracleRole(oracle);

        vm.warp(minEndOfElectionTimestamp + 1);
        vm.prank(oracle);
        vm.expectRevert();
        electionOracle.finalizeElectionResult(ElectionOracle.ElectionResult.Trump);
    }

    // ====================
    // MISCELLANEOUS TESTS
    // ====================

    function testMinEndOfElectionTimestamp() public view {
        assertEq(electionOracle.minEndOfElectionTimestamp(), minEndOfElectionTimestamp);
    }
}
