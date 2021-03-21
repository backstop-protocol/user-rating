pragma solidity 0.5.16;

import { ClaimMachine } from "../score/ScoringMachine.sol";

contract MockScoreMachine is ClaimMachine {
    function adjustSpeedMock(bytes32 asset, int112 dspeed) public {
        super.adjustSpeed(asset, dspeed);
    }

    function claimMock(bytes32 user, bytes32 asset) public returns(uint112 claimAmount) {
        claimAmount = super.claim(user,asset);
    }

    function updateScoreMock(bytes32 user, bytes32 asset, int112 dbalance) public {
        super.updateScore(user, asset, dbalance);
    }

    function slashScoreMock(bytes32 user, bytes32 asset, int112 dbalance) public {
        super.slashScore(user, asset, dbalance);
    }
}