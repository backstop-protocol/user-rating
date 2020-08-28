pragma solidity 0.5.16;

contract MockConnector {

    uint256 GLOBAL_SCORE = 100e18; // 100 units
    uint256 USER_SCORE = 10e18;    // 10 units

    function getUserScore(bytes32 user) external view returns (uint256) {
        user; // shh
        return USER_SCORE;
    }

    function getGlobalScore() external view returns (uint256) {
        return GLOBAL_SCORE;
    }

    function toUser(bytes32 user) external pure returns (address) {
        return address(uint160(bytes20(user)));
    }

    function ethExit() external {
        // Empty function to let Jar perform delegatecall
    }
}