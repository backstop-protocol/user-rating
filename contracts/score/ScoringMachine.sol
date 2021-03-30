pragma solidity ^0.5.12;

import { Ownable } from "../../openzeppelin-contracts/contracts/ownership/Ownable.sol";

contract ScoringMachine is Ownable {
    uint96 constant INDEX_FACTOR = uint96(1e10); // the basic unit will be 1e(-8) score

    struct AssetUserData {
        // total score so far
        uint96 score; // up to 10Be18

        // current balance
        uint96 balance; // up to 10Be18

        // index of score distribution
        uint64 lastScoreIndex; // up to 1e18   
    }

    struct AssetGlobalData {
        uint96 balance;
        uint64 speed;
        uint64 scoreIndex;
        uint32 lastUpdateBlock;
    }

    struct AssetData {
        AssetGlobalData globalData;
        // mapping from user to data
        mapping(bytes32 => AssetUserData) userData;
    }

    struct DistributionData {
        uint speed;
        uint scoreNormFactor;
        uint lastSpeedUpdateBlock;
        uint totalDistributed;

        // how much each user already claimed
        mapping(bytes32 => uint) claimed;
    }

    // mapping from asset to data
    mapping(bytes32 => AssetData) internal assetData;

    // mapping form asset to distribution data
    mapping(bytes32 => DistributionData) internal assetDistributionData;

    function getUserData(bytes32 asset, bytes32 user) public view returns(uint96 score, uint96 balance, uint64 lastScoreIndex) {
        AssetUserData storage data = assetData[asset].userData[user];
        
        score = data.score;
        balance = data.balance;
        lastScoreIndex = data.lastScoreIndex;
    }

    function getGlobalData(bytes32 asset) public view returns(uint96 balance, uint64 speed, uint64 scoreIndex, uint32 lastUpdateBlock) {
        AssetGlobalData storage data = assetData[asset].globalData;

        balance = data.balance;
        speed = data.speed;
        scoreIndex = data.scoreIndex;
        lastUpdateBlock = data.lastUpdateBlock;
    }

    function getDistributionData(bytes32 asset) public view returns(uint speed, uint scoreNormFactor, uint lastSpeedUpdateBlock, uint totalDistributed) {
        DistributionData storage data = assetDistributionData[asset];

        speed = data.speed;
        scoreNormFactor = data.scoreNormFactor;
        lastSpeedUpdateBlock = data.lastSpeedUpdateBlock;
        totalDistributed = data.totalDistributed;
    }

    function setSpeed(bytes32 asset, uint speed, uint scoreNormFactor, uint blockNumber) internal {
        require(blockNumber <= uint32(-1), "setSpeed: blockNumber-overflow");
        updateAssetScore(bytes32(0), asset, 0, 0, uint32(blockNumber));

        require(speed <= uint64(-1), "setSpeed: speed-overflow");        
        assetData[asset].globalData.speed = uint64(speed);

        DistributionData storage data = assetDistributionData[asset];

        require(blockNumber >= data.lastSpeedUpdateBlock, "setSpeed: blockNumber-overflow");
        uint newlyDistributed = (blockNumber - data.lastSpeedUpdateBlock) * data.speed;
        require(newlyDistributed <= uint128(-1),"setSpeed: newly-distributed-overflow");

        require(data.totalDistributed <= uint128(-1), "setSpeed: totalDistributed overflow");
        data.totalDistributed += newlyDistributed;
        data.speed = speed;
        data.lastSpeedUpdateBlock = blockNumber;

        require(scoreNormFactor <= uint96(-1), "setSpeed: scoreNormFactor-overflow");
        data.scoreNormFactor = scoreNormFactor;
    }

    function slashAssetScore(AssetUserData storage userData, AssetGlobalData storage globalData, uint96 balanceDiff) internal {
        uint64 scoreIndexDiff = sub64(globalData.scoreIndex, userData.lastScoreIndex);
        uint96 slashedScore = mul96(uint96(scoreIndexDiff), balanceDiff);

        // first update balances, only then update index. as slashed score should be distributed evenly among new balances
        userData.balance = sub96(userData.balance, balanceDiff);
        globalData.balance = sub96(globalData.balance, balanceDiff);

        uint96 slashedIndex = slashedScore / globalData.balance;
        require(slashedIndex <= uint64(-1), "slashAssetScore: slashedInex-overflow");

        globalData.scoreIndex = add64(globalData.scoreIndex, uint64(slashedIndex));

    }

    function calcScoreIndex(AssetGlobalData storage globalData, uint32 blockNumber) internal view returns(uint64) {
        if(globalData.balance == 0) return globalData.scoreIndex;

        uint64 diff = mulmulmuldiv(globalData.speed, INDEX_FACTOR, sub32(blockNumber, globalData.lastUpdateBlock), globalData.balance);

        return add64(globalData.scoreIndex, diff);
    }

    function updateAssetScore(bytes32 user, bytes32 asset, int96 dbalance, uint96 expectedBalance, uint32 blockNumber) internal {
        AssetGlobalData storage globalData = assetData[asset].globalData;
        AssetUserData storage userData = assetData[asset].userData[user];

        uint96 expectedBalanceBeforeUpdate = add96(expectedBalance, dbalance);
        if(expectedBalanceBeforeUpdate < userData.balance) {
            slashAssetScore(userData, globalData, sub96(userData.balance, expectedBalanceBeforeUpdate));
        }

        // this supports user who entered before the upgrade
        if(userData.balance == 0) dbalance = int96(expectedBalance);

        globalData.scoreIndex = calcScoreIndex(globalData, blockNumber);
        globalData.balance = add96(globalData.balance, dbalance);
        globalData.lastUpdateBlock = blockNumber;

        // update user data
        uint96 userScoreDiff = mul96(sub64(globalData.scoreIndex, userData.lastScoreIndex), userData.balance);
        userData.score = add96(userData.score, userScoreDiff);
        userData.lastScoreIndex = globalData.scoreIndex;
        userData.balance = add96(userData.balance, dbalance);
    }

    function getScore(bytes32 user, bytes32 asset, uint32 blockNumber) public view returns(uint96 score) {
        AssetGlobalData storage globalData = assetData[asset].globalData;
        AssetUserData storage userData = assetData[asset].userData[user];
        
        uint64 scoreIndex = calcScoreIndex(globalData, blockNumber);
        uint96 userScore = add96(userData.score, mul96(sub64(scoreIndex, userData.lastScoreIndex), userData.balance));
        return mul96(userScore, uint96(assetDistributionData[asset].scoreNormFactor));
    }

    function getGlobalScore(bytes32 asset, uint32 blockNumber) public view returns(uint96 score) {
        DistributionData storage data = assetDistributionData[asset];
        require(data.totalDistributed <= uint96(-1), "getGlobalScore: totalDistributed-overflow");
        require(blockNumber >= data.lastSpeedUpdateBlock, "getGlobalScore: blockNumber-overflow");
        require(data.speed <= uint64(-1), "getGlobalScore: speed-overflow");

        uint globalScore = data.totalDistributed + (blockNumber - data.lastSpeedUpdateBlock) * data.speed;
        
        require(data.scoreNormFactor <= uint128(-1), "getGlobalScore: scoreNormFactor-overflow");
        require(globalScore <= uint128(-1), "getGlobalScore: globalScore-overflow");

        uint result = data.scoreNormFactor * globalScore;
        require(result <= uint96(-1), "getGlobalScore: score-overflow");
        score = uint96(result);
    }

    function getCurrentBalance(bytes32 user, bytes32 asset) public view returns(uint96 balance) {
        return assetData[asset].userData[user].balance;
    }

    function claimScore(bytes32 user, bytes32 asset, uint96 expectedBalance, uint32 blockNumber) internal returns(uint96 score) {
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
    function add96(uint96 x, uint96 y) internal pure returns (uint96 z) {
        uint result = uint(x) + uint(y);
        require(result <= uint96(-1), "add96: overflow");
        z = uint96(result);
    }

    function add96(uint96 x, int96 y) internal pure returns (uint96 z) {
        int result = int(x) + int(y);
        require(result >= 0, "add96: underflow");
        require(result <= uint96(-1), "add96: overflow");

        z = uint96(uint(result));
    }

    function add64(uint64 x, uint64 y) internal pure returns (uint64 z) {
        uint result = uint(x) + uint(y);
        require(result <= uint64(-1), "add96: overflow");
        z = uint64(result);        
    }

    function add64(uint64 x, int64 y) internal pure returns (uint64 z) {
        int result = int(x) + int(y);
        require(result >= 0, "add64: underflow");
        require(result <= uint64(-1), "add96: overflow");

        z = uint64(uint(result));
    }

    function sub96(uint96 x, uint96 y) internal pure returns (uint96 z) {
        require(x >= y, "sub96: overflow");
        z = x - y;

        return z;
    }

    function sub64(uint64 x, uint64 y) internal pure returns (uint64 z) {
        z = uint64(sub96(uint96(x), uint96(y)));
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

    function mulmulmuldiv(uint64 x, uint96 y, uint32 z, uint96 w) internal pure returns(uint64 r) {
        // x * y * z is atmost 192 bits, so can't have an overflow
        uint result = uint(x) * uint(y) * uint(z) / uint(w);

        require(result <= uint64(-1), "mulmulmuldiv: overflow");
        r = uint64(result);
    }
}
