pragma solidity ^0.5.12;

import { Ownable } from "../../openzeppelin-contracts/contracts/ownership/Ownable.sol";

contract ScoringMachine is Ownable {
    struct AssetScore {
        // total score so far
        uint96 score;

        // current balance
        uint96 balance;

        // time when last update was
        uint32 lastTime;

        // index value of gov
        uint32 lastGovIndex;        
    }

    struct User {
        // Three epochs. One is final. One ended, but could be slashed. And one is current.
        AssetScore[3] scores;
    }

    // user is bytes32 (will be the sha3 of address or cdp number)
    mapping(bytes32 => mapping(bytes32 => User)) internal userScore;

    bytes32 constant public GLOBAL_USER = bytes32(0x0);

    uint32 public start; // start time of the campaign;
    uint32 constant public EPOCH = 1 days; // TODO - decide

    function spin() external onlyOwner { // start a new round
        start = uint32(now);
    }

    function getLatestScoreIndex(
        bytes32 user,
        bytes32 asset
    ) internal view returns(uint latest, uint32[3] memory last) {
        User memory userData = userScore[user][asset];
        uint32 last0 = userData.scores[0].lastTime;
        uint32 last1 = userData.scores[1].lastTime;
        uint32 last2 = userData.scores[2].lastTime;

        last[0] = last0; last[1] = last1; last[2] = last2;

        if((last0 > last1) && (last0 > last2)) latest = 0;
        else if(last1 > last2) latest = 1;
        else latest = 2;
    }

    function inEpoch(uint32 t0, uint32 t1) internal pure returns(bool) {
        uint32 t0Epoch = (t0 / EPOCH) * EPOCH;
        return add32(t0Epoch, EPOCH) > t1;
    }

    function inPrevEpoch(uint32 t0, uint32 t1) internal pure returns(bool) {
        return inEpoch(add32(t0, EPOCH), t1);
    }

    function updateAssetScore(bytes32 user, bytes32 asset, int96 dbalance, uint32 time, uint32 govIndex) internal {
        (uint latest, uint32[3] memory last) = getLatestScoreIndex(user, asset);
        uint32 t0 = last[latest] == 0 ? time : last[latest];

        AssetScore storage score = userScore[user][asset].scores[latest];
        uint96 scoreBefore = score.score;
        uint96 balanceBefore = score.balance;
        uint32  govBefore = score.lastGovIndex;

        uint32 dgov = sub32(govIndex, govBefore);

        if(! inEpoch(t0, time)) {
            latest = (latest + 1) % 3;
        }
        
        score = userScore[user][asset].scores[latest];

        score.score = uint96(add(scoreBefore, mul(balanceBefore, dgov)));
        score.balance = uint96(add(balanceBefore, dbalance));
        
        score.lastTime = uint32(time);
        score.lastGovIndex = govIndex;
    }

    function slashAssetScore(bytes32 user, bytes32 asset, uint96 dbalance, uint32 time, uint32 govIndex, uint32 dgov) internal {
        // make sure there is a record current time, that is slashable
        updateAssetScore(user, asset, 0, time, govIndex);

        (uint latest, uint32[3] memory last) = getLatestScoreIndex(user, asset);

        for(uint i = 0 ; i < 2 ; i++) {
            uint index = (latest + 2 + i) % 3;

            if(! (inEpoch(last[index], time) || inPrevEpoch(last[index], time))) continue;

            AssetScore storage score = userScore[user][asset].scores[index];
            score.balance = add(score.balance, -int96(dbalance));
            score.score = add(score.score, -int96(mul(dgov, dbalance)));
        }
    }

    function updateScore(bytes32 user, bytes32 asset, int96 dbalance, uint32 time, uint32 govIndex) internal {
        updateAssetScore(user, asset, dbalance, time, govIndex);
        updateAssetScore(GLOBAL_USER, asset, dbalance, time, govIndex);
    }

    function slashScore(bytes32 user, bytes32 asset, uint96 dbalance, uint32 time, uint32 govIndex, uint32 dgov) internal {
        slashAssetScore(user, asset, dbalance, time, govIndex, dgov);
        slashAssetScore(GLOBAL_USER, asset, dbalance, time, govIndex, dgov);
    }    

    function getScore(bytes32 user, bytes32 asset, uint32 time) public view returns(uint96 score) {
        (uint latest, uint32[3] memory last) = getLatestScoreIndex(user, asset);
        uint index = 0;
        for(uint i = 0 ; i < 3 ; i++) {
            index = (latest + 1 + i) % 3;
            if(inEpoch(last[index], time)) break;
        }

        AssetScore storage currScore = userScore[user][asset].scores[index];
        uint32 dtime = sub32(time, last[index]);
        return add(currScore.score, mul(currScore.balance, dtime));
    }

    function getGlobalScore(bytes32 asset, uint32 time) public view returns(uint96 score) {
        return getScore(GLOBAL_USER, asset, time);
    }

    function getCurrentBalance(bytes32 user, bytes32 asset) public view returns(uint96 balance) {
        (uint latest,) = getLatestScoreIndex(user, asset);
        balance = userScore[user][asset].scores[latest].balance;
    }

    // Math functions without errors
    // ==============================
    function add(uint96 x, uint96 y) internal pure returns (uint96 z) {
        z = x + y;
        if(!(z >= x)) return 0;

        return z;
    }

    function add(uint96 x, int96 y) internal pure returns (uint96 z) {
        z = x + uint96(y);
        if(!(y >= 0 || z <= x)) return 0;
        if(!(y <= 0 || z >= x)) return 0;

        return z;
    }

    function add32(uint32 x, uint32 y) internal pure returns (uint32 z) {
        z = x + y;
        if(!(z >= x)) return 0;

        return z;
    }

    function sub(uint96 x, uint96 y) internal pure returns (uint96 z) {
        if(!(y <= x)) return 0;
        z = x - y;

        return z;
    }

    function sub32(uint32 x, uint32 y) internal pure returns (uint32 z) {
        if(!(y <= x)) return 0;
        z = x - y;

        return z;
    }    

    function mul(uint96 x, uint96 y) internal pure returns (uint96 z) {
        if (x == 0) return 0;

        z = x * y;
        if(!(z / x == y)) return 0;

        return z;
    }
}

contract ClaimMachine is ScoringMachine {
    bytes32 constant public GOV_USER = bytes32(uint(0x1));

    struct UserClaimInfo {
        uint96 scoreClaimed;
    }

    struct ClaimInfo {
        uint96 globalScoreClaimed;
        uint96 govClaimed;

        // user => user claim info
        mapping(bytes32 => UserClaimInfo) userInfo;
    }

    // asset => claimInfo
    mapping(bytes32 => ClaimInfo) claimInfo;

    // asset => slash speed
    mapping(bytes32 => uint96) slashSpeed;

    function adjustSpeed(bytes32 asset, int96 dspeed, uint32 time, uint96 newSlashSpeed) internal {
        super.updateScore(GOV_USER, asset, dspeed, time, time);
        slashSpeed[asset] = newSlashSpeed;
    }

    function getGovScore(bytes32 asset, uint32 time) public view returns(uint96 score) {
        return getScore(GOV_USER, asset, time);
    }

    function updateScore(bytes32 user, bytes32 asset, int96 dbalance, uint32 time) internal {
        // if there is an overflow, then sfyl
        uint32 govIndex = uint32(getGovScore(asset, time));
        super.updateScore(user, asset, dbalance, time, govIndex);
    }

    function slashScore(bytes32 user, bytes32 asset, uint96 dbalance, uint32 time) internal {
        // if there is an overflow, then sfyl
        uint32 govIndex = uint32(getGovScore(asset, time));
        uint32 dgov = uint32(mul(slashSpeed[asset], 2 * EPOCH));
        super.slashScore(user, asset, dbalance, time, govIndex, dgov);
    }

    function claim(bytes32 user, bytes32 asset) internal returns(uint96 claimAmount) {
        uint32 time = uint32((now / EPOCH) * EPOCH - EPOCH);

        uint96 totalScore = getGlobalScore(asset, time);
        uint96 userScore = getScore(user, asset, time);

        uint96 globalScoreClaimed = claimInfo[asset].globalScoreClaimed;
        uint96 userScoreClaimed = claimInfo[asset].userInfo[user].scoreClaimed;

        claimAmount = sub(userScore, userScoreClaimed) / sub(totalScore, globalScoreClaimed);

        claimInfo[asset].globalScoreClaimed = add(claimInfo[asset].globalScoreClaimed , userScore);
        claimInfo[asset].userInfo[user].scoreClaimed = add(claimInfo[asset].userInfo[user].scoreClaimed, userScore);        
        claimInfo[asset].govClaimed = add(claimInfo[asset].govClaimed, claimAmount);
    }
}