// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

enum ElectionResult {
    NotSet,  // Initial/default value when the election result has not been set yet
    Trump,   // Election result for candidate Trump
    Harris,  // Election result for candidate Harris
    Other    // Election result for any other candidate
}

interface IElectionOracle {

    // Function to retrieve the finalized election result.
    function getElectionResult() external view returns (ElectionResult);

    // Function to check if the election has been finalized.
    function isElectionFinalized() external view returns (bool);
}