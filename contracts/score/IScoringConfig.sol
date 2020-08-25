pragma solidity 0.5.16;

/**
 * @notice Scroing Config interface
 */
interface IScoringConfig {

    function getUserScore(address user, address token) external view returns (uint256);
    function getGlobalScore(address token) external view returns (uint256);
}