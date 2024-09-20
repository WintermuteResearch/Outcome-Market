// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/ElectionOracle.sol";

contract DeployElectionOracle is Script {
    function run() external {
        // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Define the owner, oracle, and election timestamp
        address owner = 0xc26d7EF337e01a5cC5498D3cc2ff0610761ae637; // Specify the actual owner address here
        address oracle = 0xc26d7EF337e01a5cC5498D3cc2ff0610761ae637; // Specify the actual oracle address here
        //uint256 expectedEndOfElectionTimestamp = 1730878800; // November 6, 2024, 00:00:00 EST
        //uint256 minEndOfElectionTimestamp = expectedEndOfElectionTimestamp + 24 hours;
        uint256 currentTimestamp = block.timestamp + 1 minutes;

        // Deploy the ElectionOracle contract
        //ElectionOracle electionOracle = new ElectionOracle(owner, oracle, minEndOfElectionTimestamp);
        ElectionOracle electionOracle = new ElectionOracle(owner, oracle, currentTimestamp);

        console.log("ElectionOracle deployed at:", address(electionOracle));

        vm.stopBroadcast();
    }
}
