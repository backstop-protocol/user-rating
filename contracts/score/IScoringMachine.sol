pragma solidity 0.5.16;

/**
 * @dev ScroingMachine interface
 */
interface IScoringMachine {
    function getScore(bytes32 user, bytes32 asset, uint time, uint spinStart, uint checkPointHint) external view returns(uint score);
}