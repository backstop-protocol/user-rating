pragma solidity 0.5.16;

interface IJarConfig {
    function getUserScore(address user, address token) external view returns (uint256);
    function getGlobalScore(address token) external view returns (uint256);
}