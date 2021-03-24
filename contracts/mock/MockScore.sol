pragma solidity 0.5.16;

import { ClaimMachine } from "../score/ScoringMachine.sol";

contract MockScoreMachine is ClaimMachine {
    function adjustSpeedMock(bytes32 asset, int112 dspeed, uint32 time) public {
        super.adjustSpeed(asset, dspeed, time);
    }

    function claimMock(bytes32 user, bytes32 asset) public returns(uint112 claimAmount) {
        claimAmount = super.claim(user,asset);
    }

    function updateScoreMock(bytes32 user, bytes32 asset, int112 dbalance, uint32 time) public {
        super.updateScore(user, asset, dbalance, time);
    }

    function slashScoreMock(bytes32 user, bytes32 asset, int112 dbalance, uint32 time) public {
        super.slashScore(user, asset, dbalance, time);
    }
}