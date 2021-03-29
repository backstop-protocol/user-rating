pragma solidity 0.5.16;


import { ScoringMachine } from "../score/ScoringMachine.sol";

contract MockScoreMachine is ScoringMachine {
    function setSpeedMock(bytes32 asset, uint speed, uint scoreNormFactor, uint blockNumber) public {
        super.setSpeed(asset, speed, scoreNormFactor, blockNumber);
    }

    function claimScoreMock(bytes32 user, bytes32 asset, uint96 expectedBalance, uint32 blockNumber) public returns(uint96 score) {
        score = super.claimScore(user,asset,expectedBalance,blockNumber);
    }

    function updateScoreMock(bytes32 user, bytes32 asset, int96 dbalance, uint96 expectedBalance, uint32 blockNumber) public {
        super.updateAssetScore(user, asset, dbalance, expectedBalance, blockNumber);
    }
}