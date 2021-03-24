pragma solidity 0.5.16;

import { ClaimMachine } from "../score/ScoringMachine.sol";

contract MockScoreMachine is ClaimMachine {
    function adjustSpeedMock(bytes32 asset, int96 dspeed, uint32 time, uint96 slashSpeed) public {
        super.adjustSpeed(asset, dspeed, time, slashSpeed);
    }

    function claimMock(bytes32 user, bytes32 asset) public returns(uint96 claimAmount) {
        claimAmount = super.claim(user,asset);
    }

    function updateScoreMock(bytes32 user, bytes32 asset, int96 dbalance, uint32 time) public {
        super.updateScore(user, asset, dbalance, time);
    }

    function slashScoreMock(bytes32 user, bytes32 asset, uint96 dbalance, uint32 time) public {
        super.slashScore(user, asset, dbalance, time);
    }
}