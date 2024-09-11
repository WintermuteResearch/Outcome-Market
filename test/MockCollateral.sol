pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockCollateral is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address _receiver, uint256 _amount) public {
        _mint(_receiver, _amount);
    }
}
