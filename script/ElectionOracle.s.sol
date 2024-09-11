// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/ElectionOracle.sol";

contract DeployElectionOracle is Script {
    function run() external {
        vm.startBroadcast();

        // Define the owner, oracle, and election timestamp
        address owner = 0xabCd123456789012345678901234567890aBcD12; // Specify the actual owner address here
        address oracle = 0x1234567890123456789012345678901234567890; // Specify the actual oracle address here
        uint256 expectedEndOfElectionTimestamp = 1730878800; // November 6, 2024, 00:00:00 EST
        uint256 minEndOfElectionTimestamp = expectedEndOfElectionTimestamp + 24 hours;

        // Deploy the ElectionOracle contract
        ElectionOracle electionOracle = new ElectionOracle(owner, oracle, minEndOfElectionTimestamp);

        console.log("ElectionOracle deployed at:", address(electionOracle));

        vm.stopBroadcast();
    }
}
