pragma solidity ^0.8.25;

import {Vm, Test} from "forge-std/Test.sol";
import {OutcomeERC20} from "../src/OutcomeERC20.sol";
import {ElectionResult} from "../interfaces/IElectionOracle.sol";

contract OutcomeERC20Test is Test {
    OutcomeERC20 public outcomeToken;

    function setUp() public {
        outcomeToken = new OutcomeERC20("TrumpConditional", "TRUMP", ElectionResult.Trump);
    }

    function testFuzz_MintWhenOwner(uint256 _mintAmount, address _receiver) public {
        vm.assume(_receiver != address(0));
        outcomeToken.mint(_receiver, _mintAmount);
        assertEq(_mintAmount, outcomeToken.balanceOf(_receiver));
        assertEq(_mintAmount, outcomeToken.totalSupply());
    }

    function testFuzz_BurnWhenOwner(uint256 _initialSupply, address _receiver) public {
        vm.assume(_receiver != address(0));
        outcomeToken.mint(_receiver, _initialSupply);
        outcomeToken.burn(_receiver, _initialSupply);
    }
}
