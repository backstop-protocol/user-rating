pragma solidity ^0.5.12;

import { Ownable } from "../../openzeppelin-contracts/contracts/ownership/Ownable.sol";

contract ScoringMachine is Ownable {
    uint256 constant INDEX_FACTOR = 1e36;

    struct AssetUserData {
        // total score so far
        uint96 score;

        // current balance
        uint128 balance;

        // index of score distribution
        uint256 lastScoreIndex;
    }

    struct AssetGlobalData {
        uint128 balance;
        uint96  speed;
        uint32  lastUpdateBlock;        
        uint256 scoreIndex;
    }

    struct AssetData {
        AssetGlobalData globalData;
        // mapping from user to data
        mapping(bytes32 => AssetUserData) userData;
    }

    struct DistributionData {
        uint96 speed;
        uint32 lastSpeedUpdateBlock;
        uint96 totalDistributed;

        // how much each user already claimed
        mapping(bytes32 => uint) claimed;
    }

    // mapping from asset to data
    mapping(bytes32 => AssetData) internal assetData;

    // mapping form asset to distribution data
    mapping(bytes32 => DistributionData) internal assetDistributionData;

    function getUserData(bytes32 asset, bytes32 user) public view returns(uint128 score, uint128 balance, uint256 lastScoreIndex) {
        AssetUserData storage data = assetData[asset].userData[user];
        
        score = data.score;
        balance = data.balance;
        lastScoreIndex = data.lastScoreIndex;
    }

    function getGlobalData(bytes32 asset) public view returns(uint128 balance, uint96 speed, uint256 scoreIndex, uint32 lastUpdateBlock) {
        AssetGlobalData storage data = assetData[asset].globalData;

        balance = data.balance;
        speed = data.speed;
        scoreIndex = data.scoreIndex;
        lastUpdateBlock = data.lastUpdateBlock;
    }

    function getDistributionData(bytes32 asset) public view returns(uint96 speed, uint32 lastSpeedUpdateBlock, uint96 totalDistributed) {
        DistributionData storage data = assetDistributionData[asset];

        speed = data.speed;
        lastSpeedUpdateBlock = data.lastSpeedUpdateBlock;
        totalDistributed = data.totalDistributed;
    }

    function setSpeed(bytes32 asset, uint96 speed, uint32 blockNumber) internal {
        updateAssetScore(bytes32(0), asset, 0, 0, uint32(blockNumber));

        assetData[asset].globalData.speed = speed;

        DistributionData storage data = assetDistributionData[asset];

        require(blockNumber >= data.lastSpeedUpdateBlock, "setSpeed: blockNumber-overflow");
        uint96 newlyDistributed = mul96(data.speed, sub32(blockNumber, data.lastSpeedUpdateBlock));
        data.totalDistributed = add96(data.totalDistributed, newlyDistributed);
        data.speed = speed;
        data.lastSpeedUpdateBlock = blockNumber;
    }

    function deltaIndexToScore(uint256 dScoreIndex, uint128 balance) internal pure returns(uint96 dscore) {
        uint256 dscore256 = mul256(dScoreIndex, balance) / INDEX_FACTOR;
        require(dscore256 <= uint96(-1), "deltaIndexToScore: overflow");

        dscore = uint96(dscore256);
    }

    function deltaScoreToIndex(uint96 dscore, uint128 balance) internal pure returns(uint256 dindex) {
        dindex = mul256(dscore, INDEX_FACTOR) / balance;
    }

    function slashAssetScore(AssetUserData storage userData, AssetGlobalData storage globalData, uint128 balanceDiff) internal {
        uint256 scoreIndexDiff = sub256(globalData.scoreIndex, userData.lastScoreIndex);
        uint96 slashedScore = deltaIndexToScore(scoreIndexDiff, balanceDiff);

        // first update balances, only then update index. as slashed score should be distributed evenly among new balances
        userData.balance = sub128(userData.balance, balanceDiff);
        globalData.balance = sub128(globalData.balance, balanceDiff);

        uint256 slashedIndex =  deltaScoreToIndex(slashedScore, globalData.balance);
        globalData.scoreIndex = add256(globalData.scoreIndex, slashedIndex);

    }

    function calcScoreIndex(AssetGlobalData storage globalData, uint32 blockNumber) internal view returns(uint256) {
        if(globalData.balance == 0) return globalData.scoreIndex;

        uint96 dscore = mul96(globalData.speed, sub32(blockNumber, globalData.lastUpdateBlock));
        uint256 diff = deltaScoreToIndex(dscore, globalData.balance);

        return add256(globalData.scoreIndex, diff);
    }

    function updateAssetScore(bytes32 user, bytes32 asset, int128 dbalance, uint128 expectedBalance, uint32 blockNumber) internal {
        AssetGlobalData storage globalData = assetData[asset].globalData;
        AssetUserData storage userData = assetData[asset].userData[user];

        uint128 expectedBalanceBeforeUpdate = sub128(expectedBalance, dbalance);
        if(expectedBalanceBeforeUpdate < userData.balance) {
            slashAssetScore(userData, globalData, sub128(userData.balance, expectedBalanceBeforeUpdate));
        }

        // this supports user who entered before the upgrade
        if(userData.balance == 0) dbalance = int128(expectedBalance);

        globalData.scoreIndex = calcScoreIndex(globalData, blockNumber);
        globalData.balance = add128(globalData.balance, dbalance);
        globalData.lastUpdateBlock = blockNumber;

        // update user data
        uint256 dindex = sub256(globalData.scoreIndex, userData.lastScoreIndex);
        uint96 userScoreDiff = deltaIndexToScore(dindex, userData.balance);
        userData.score = add96(userData.score, userScoreDiff);
        userData.lastScoreIndex = globalData.scoreIndex;
        userData.balance = add128(userData.balance, dbalance);
    }

    function getScore(bytes32 user, bytes32 asset, uint32 blockNumber) public view returns(uint96 score) {
        AssetGlobalData storage globalData = assetData[asset].globalData;
        AssetUserData storage userData = assetData[asset].userData[user];
        
        uint256 scoreIndex = calcScoreIndex(globalData, blockNumber);
        uint256 dindex = sub256(scoreIndex, userData.lastScoreIndex);
        score = add96(userData.score, deltaIndexToScore(dindex, userData.balance));
    }

    function getGlobalScore(bytes32 asset, uint32 blockNumber) public view returns(uint96 score) {
        DistributionData storage data = assetDistributionData[asset];
        require(blockNumber >= data.lastSpeedUpdateBlock, "getGlobalScore: blockNumber-overflow");

        uint96 newDist = mul96(data.speed, sub32(blockNumber, data.lastSpeedUpdateBlock));
        score = add96(data.totalDistributed, newDist);
    }

    function getCurrentBalance(bytes32 user, bytes32 asset) public view returns(uint128 balance) {
        return assetData[asset].userData[user].balance;
    }

    function claimScore(bytes32 user, bytes32 asset, uint128 expectedBalance, uint32 blockNumber) internal returns(uint96 score) {
        updateAssetScore(user, asset, 0, expectedBalance, blockNumber);
        uint96 fullScore = getScore(user, asset, blockNumber);

        uint claimedScore = assetDistributionData[asset].claimed[user];
        require(claimedScore <= uint96(-1), "claimScore: overflow");

        score = sub96(fullScore, uint96(claimedScore));

        // cannot have overflow, as summing 96 bit integer
        assetDistributionData[asset].claimed[user] += uint(score);
    }

    // Math functions
    // ==============================
    function add256(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x + y;
        require(z >= x && z >= y, "add256: overflow");
    }

    function sub256(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x >= y, "sub256: overflow");        
        z = x - y;
    }

    function mul256(uint256 x, uint256 y) internal pure returns (uint256 z) {
        if(x == 0) return 0;
        z = x * y;
        require(z / x == y, "mul256: overflow");
    }    

    function add128(uint128 x, uint128 y) internal pure returns (uint128 z) {
        uint result = uint(x) + uint(y);
        require(result <= uint128(-1), "add128: overflow");
        z = uint128(result);
    }

    function add128(uint128 x, int128 y) internal pure returns (uint128 z) {
        int result = int(x) + int(y);
        require(result >= 0, "add128: underflow");
        require(result <= uint128(-1), "add128: overflow");

        z = uint128(uint(result));
    }

    function sub128(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require(x >= y, "sub128: overflow");
        z = x - y;

        return z;
    }

    function sub128(uint128 x, int128 y) internal pure returns (uint128 z) {
        require(int128(x) >= y, "sub128: overflow");
        z = uint128(int128(x) - y);

        return z;
    }    

    function add96(uint96 x, uint96 y) internal pure returns (uint96 z) {
        uint result = uint(x) + uint(y);
        require(result <= uint96(-1), "add96: overflow");
        z = uint96(result);
    }

    function sub96(uint96 x, uint96 y) internal pure returns (uint96 z) {
        require(x >= y, "sub96: overflow");
        z = x - y;

        return z;
    } 

    function sub32(uint32 x, uint32 y) internal pure returns (uint32 z) {
        z = uint32(sub96(uint96(x), uint96(y)));
    }    

    function mul96(uint96 x, uint96 y) internal pure returns (uint96 z) {
        if (x == 0) return 0;

        uint result = uint(x) * uint(y);
        require((result / uint(x)) == uint(y), "mul96: overlow");
        require(result <= uint96(-1), "mul96: overflow");

        z = uint96(result);
    }
}
