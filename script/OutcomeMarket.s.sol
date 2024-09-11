// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IElectionOracle, ElectionResult} from "../interfaces/IElectionOracle.sol";
import {OutcomeMarket} from "../src/OutcomeMarket.sol";

contract DeployOutcomeMarket is Script {
    IERC20 public constant USDC = IERC20(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d);
    IElectionOracle public constant ORACLE = IElectionOracle(0x561eF701332e9A95aA7a5Aa1478Da0C80c630ea0);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new OutcomeMarket(USDC, ORACLE);

        vm.stopBroadcast();
    }
}
