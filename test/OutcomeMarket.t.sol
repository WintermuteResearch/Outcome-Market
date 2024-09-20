pragma solidity ^0.8.25;

import {Vm, Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {OutcomeERC20} from "../src/OutcomeERC20.sol";
import {OutcomeMarket} from "../src/OutcomeMarket.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IElectionOracle, ElectionResult} from "../interfaces/IElectionOracle.sol";
import {MockOracle} from "./MockOracle.sol";
import {MockCollateral} from "./MockCollateral.sol";

contract OutcomeMarketTest is Test {
    OutcomeERC20[2] public outcomeTokens;
    address public testTrader = 0x67711e0E2017Fa5099FEED44Dd97794FfD5685b3;
    OutcomeMarket public market;
    MockOracle public oracle;
    MockCollateral public collateralToken;

    function _mint(address _receiver, uint256 _amount, bool _shouldRevert) internal {
        collateralToken.mint(_receiver, _amount);
        vm.startPrank(_receiver);
        collateralToken.approve(address(market), _amount);
        if (_shouldRevert) {
            vm.expectRevert(OutcomeMarket.OutcomeMarket__MarketResolved.selector);
        }
        market.mint(_amount);
        vm.stopPrank();
    }

    function _resolveOracle(ElectionResult _electionResult) internal {
        oracle.finalizeElectionResult(_electionResult);
        market.resolve();
    }

    function setUp() public {
        oracle = new MockOracle(address(this), address(this), block.timestamp + 1);
        vm.warp(block.timestamp + 1000);

        collateralToken = new MockCollateral("USDC", "USDC");
        market = new OutcomeMarket(IERC20(address(collateralToken)), IElectionOracle(address(oracle)));
        outcomeTokens[0] = market.outcomeTokens(0);
        outcomeTokens[1] = market.outcomeTokens(1);
    }

    // Amount is in USDC
    function testFuzz_mintedAmounts(address _receiver, uint256 _amount) external {
        vm.assume(_receiver != address(0));
        vm.assume(_receiver != address(market));
        vm.assume(_amount < 10 ** 20);

        _mint(_receiver, _amount, false);
        //normalize to 18 decimals from 6
        uint256 _normalizedAmount = _amount * 1e12;
        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            vm.assertEq(outcomeTokens[i].balanceOf(_receiver), _normalizedAmount);
        }
    }

    function _electionResultAssumptions(uint8 _result) internal pure returns (ElectionResult _electionResult) {
        vm.assume(_result < 4);
        vm.assume(_result != 0);
        _electionResult = ElectionResult(_result);
    }

    function testFuzz_revertWhen_MintAfterResolution(address _receiver, uint256 _amount, uint8 _result) external {
        vm.assume(_receiver != address(0));
        vm.assume(_receiver != address(market));
        vm.assume(_amount < 10 ** 20);
        ElectionResult _electionResult = _electionResultAssumptions(_result);

        _resolveOracle(_electionResult);
        _mint(_receiver, _amount, true);
    }

    function testFuzz_revertWhen_resolveAfterResolution(uint256 _amount, address _receiver, uint8 _result) external {
        vm.assume(_receiver != address(0));
        vm.assume(_receiver != address(market));
        vm.assume(_amount < 10 ** 20);
        ElectionResult _electionResult = _electionResultAssumptions(_result);

        _mint(_receiver, _amount, false);
        _resolveOracle(_electionResult);

        vm.expectRevert(OutcomeMarket.OutcomeMarket__MarketResolved.selector);
        market.resolve();
    }

    function testFuzz_resolve(uint256 _amount, address _receiver, uint8 _result) external {
        vm.assume(_receiver != address(0));
        vm.assume(_receiver != address(market));
        vm.assume(_amount < 10 ** 20);
        ElectionResult _electionResult = _electionResultAssumptions(_result);

        _mint(_receiver, _amount, false);
        address winningToken = address(0);
        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            if (outcomeTokens[i].marketOutcomeType() == _electionResult) {
                winningToken = address(outcomeTokens[i]);
            }
        }
        if (winningToken == address(0)) {
            winningToken = market.OTHER_WINNER();
        }

        oracle.finalizeElectionResult(_electionResult);
        vm.expectEmit(true, false, false, false);
        emit OutcomeMarket.MarketResolved(winningToken);
        market.resolve();
    }

    function testFuzz_revertWhen_redeemBeforeResolution(address _receiver, uint256 _amount) external {
        vm.assume(_receiver != address(0));
        vm.assume(_receiver != address(market));
        vm.assume(_amount < 10 ** 20);

        _mint(_receiver, _amount, false);

        vm.prank(_receiver);
        vm.expectRevert(OutcomeMarket.OutcomeMarket__MarketNotResolved.selector);
        market.resolve();
    }

    // In all cases where there are no trading, i should get back exactly how much USDC I minted
    function testFuzz_redeemNoTrading(address _receiver, uint256 _amount, uint8 _result) external {
        vm.assume(_receiver != address(0));
        vm.assume(_receiver != address(market));
        vm.assume(_amount < 10 ** 20);
        vm.assume(_amount > 0);
        ElectionResult _electionResult = _electionResultAssumptions(_result);

        _mint(_receiver, _amount, false);

        _resolveOracle(_electionResult);

        uint256 _preBalance = collateralToken.balanceOf(_receiver);
        vm.prank(_receiver);
        market.redeem();
        uint256 _postBalance = collateralToken.balanceOf(_receiver);
        vm.assertApproxEqAbs(_preBalance + _amount, _postBalance, 1);
        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            if (outcomeTokens[i].marketOutcomeType() == _electionResult || _electionResult == ElectionResult.Other) {
                vm.assertEq(outcomeTokens[i].balanceOf(_receiver), 0);
            }
        }
    }

    function testFuzz_redeemWhenTrading(address _receiver, uint256 _amount, uint8 _result) external {
        vm.assume(_receiver != address(0));
        vm.assume(_receiver != address(market));
        vm.assume(_amount < 10 ** 20);
        vm.assume(_amount > 0);

        vm.assume(_receiver != testTrader);

        ElectionResult _electionResult = _electionResultAssumptions(_result);

        _mint(_receiver, _amount, false);

        _mint(testTrader, _amount, false);

        // mimic a trade s.t. each party only has a single token
        vm.startPrank(_receiver);
        outcomeTokens[0].transfer(testTrader, outcomeTokens[0].balanceOf(_receiver));
        vm.stopPrank();
        vm.startPrank(testTrader);
        outcomeTokens[1].transfer(_receiver, outcomeTokens[1].balanceOf(testTrader));
        vm.stopPrank();
        _resolveOracle(_electionResult);

        uint256 _expectedReturnsTestTrader;
        uint256 _expectedReturnsReceiver;
        address _winningToken;
        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            if (_electionResult == ElectionResult.Other) {
                _expectedReturnsReceiver += outcomeTokens[i].balanceOf(_receiver);
                _expectedReturnsTestTrader += outcomeTokens[i].balanceOf(testTrader);
            } else if (outcomeTokens[i].marketOutcomeType() == _electionResult) {
                _expectedReturnsReceiver += outcomeTokens[i].balanceOf(_receiver);
                _expectedReturnsTestTrader += outcomeTokens[i].balanceOf(testTrader);
                _winningToken = address(outcomeTokens[i]);
            }
        }

        uint256 availableCollateral = collateralToken.balanceOf(address(market));
        if (_electionResult == ElectionResult.Other) {
            _expectedReturnsReceiver = Math.mulDiv(
                _expectedReturnsReceiver,
                availableCollateral,
                (outcomeTokens[0].totalSupply() + outcomeTokens[1].totalSupply())
            );
        } else {
            _expectedReturnsReceiver =
                Math.mulDiv(_expectedReturnsReceiver, availableCollateral, IERC20(_winningToken).totalSupply());
        }

        vm.prank(_receiver);
        market.redeem();

        availableCollateral = collateralToken.balanceOf(address(market));
        if (_electionResult == ElectionResult.Other) {
            _expectedReturnsTestTrader = Math.mulDiv(
                _expectedReturnsTestTrader,
                availableCollateral,
                (outcomeTokens[0].totalSupply() + outcomeTokens[1].totalSupply())
            );
        } else {
            if (IERC20(_winningToken).totalSupply() == 0) {
                _expectedReturnsTestTrader = 0;
            } else {
                _expectedReturnsTestTrader =
                    Math.mulDiv(_expectedReturnsTestTrader, availableCollateral, IERC20(_winningToken).totalSupply());
            }
        }

        vm.prank(testTrader);
        market.redeem();
        vm.assertApproxEqAbs(collateralToken.balanceOf(_receiver), _expectedReturnsReceiver, 1);
        vm.assertApproxEqAbs(collateralToken.balanceOf(testTrader), _expectedReturnsTestTrader, 1);
        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            if (outcomeTokens[i].marketOutcomeType() == _electionResult || _electionResult == ElectionResult.Other) {
                vm.assertEq(outcomeTokens[i].balanceOf(_receiver), 0);
            }
        }
    }
}
