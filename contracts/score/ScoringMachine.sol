pragma solidity ^0.5.12;

import { Ownable } from "../../openzeppelin-contracts/contracts/ownership/Ownable.sol";

contract ScoringMachine is Ownable {
    struct AssetScore {
        // total score so far
        uint112 score;

        // current balance
        uint112 balance;

        // time when last update was
        uint32 last;
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
        uint32 last0 = userData.scores[0].last;
        uint32 last1 = userData.scores[1].last;
        uint32 last2 = userData.scores[2].last;

        last[0] = last0; last[1] = last1; last[2] = last2;

        if((last0 > last1) && (last0 > last2)) latest = 0;
        else if(last1 > last2) latest = 1;
        else latest = 2;
    }

    function updateAssetScore(bytes32 user, bytes32 asset, int112 dbalance) internal {
        (uint latest, uint32[3] memory last) = getLatestScoreIndex(user, asset);
        uint112 time = uint112(now);

        uint112 dtime = sub(time, last[latest] == 0 ? start : last[latest]);
        if(dtime >= EPOCH) {
            latest = (latest + 1) % 3;
        }
        
        AssetScore storage score = userScore[user][asset].scores[latest];

        score.score = uint112(add(score.score, mul(score.balance, dtime)));
        score.balance = uint112(add(score.balance, dbalance));
        
        score.last = uint32(time);
    }

    function slashAssetScore(bytes32 user, bytes32 asset, int112 dbalance) internal {
        // make sure there is a record current time, that is slashable
        updateAssetScore(user, asset, 0);

        (uint latest, uint32[3] memory last) = getLatestScoreIndex(user, asset);
        uint32 time = uint32(now);

        for(uint i = 0 ; i < 2 ; i++) {
            uint index = (latest + 2 + i) % 3;

            if(add32(last[index], 2 * EPOCH) < time) continue;

            AssetScore storage score = userScore[user][asset].scores[index];
            score.balance = uint112(add(score.balance, dbalance));
            score.score = uint112(add(score.score, -mul(uint112(-dbalance), EPOCH)));
        }
    }

    function updateScore(bytes32 user, bytes32 asset, int112 dbalance) internal {
        updateAssetScore(user, asset, dbalance);
        updateAssetScore(GLOBAL_USER, asset, dbalance);
    }

    function slashScore(bytes32 user, bytes32 asset, int112 dbalance) internal {
        slashAssetScore(user, asset, dbalance);
        slashAssetScore(GLOBAL_USER, asset, dbalance);
    }    

    function getScore(bytes32 user, bytes32 asset, uint32 time) public view returns(uint112 score) {
        (uint latest, uint32[3] memory last) = getLatestScoreIndex(user, asset);
        uint index = 0;
        for(uint i = 0 ; i < 3 ; i++) {
            index = (latest + i) % 3;
            if(add32(last[index], EPOCH) >= time) break;
        }

        AssetScore storage currScore = userScore[user][asset].scores[index];
        uint32 dtime = sub32(time, last[index]);
        return add(currScore.score, mul(currScore.balance, dtime));
    }

    function getCurrentBalance(bytes32 user, bytes32 asset) public view returns(uint112 balance) {
        (uint latest,) = getLatestScoreIndex(user, asset);
        balance = userScore[user][asset].scores[latest].balance;
    }

    // Math functions without errors
    // ==============================
    function add(uint112 x, uint112 y) internal pure returns (uint112 z) {
        z = x + y;
        if(!(z >= x)) return 0;

        return z;
    }

    function add(uint112 x, int112 y) internal pure returns (uint112 z) {
        z = x + uint112(y);
        if(!(y >= 0 || z <= x)) return 0;
        if(!(y <= 0 || z >= x)) return 0;

        return z;
    }

    function add32(uint32 x, uint32 y) internal pure returns (uint32 z) {
        z = x + y;
        if(!(z >= x)) return 0;

        return z;
    }

    function sub(uint112 x, uint112 y) internal pure returns (uint112 z) {
        if(!(y <= x)) return 0;
        z = x - y;

        return z;
    }

    function sub32(uint32 x, uint32 y) internal pure returns (uint32 z) {
        if(!(y <= x)) return 0;
        z = x - y;

        return z;
    }    

    function mul(uint112 x, uint112 y) internal pure returns (uint112 z) {
        if (x == 0) return 0;

        z = x * y;
        if(!(z / x == y)) return 0;

        return z;
    }
}

contract ClaimMachine is ScoringMachine {
    bytes32 constant public GOV_USER = bytes32(uint(0x1));

    struct UserClaimInfo {
        uint112 scoreClaimed;
    }

    struct ClaimInfo {
        uint112 globalScoreClaimed;
        uint112 govClaimed;

        // user => user claim info
        mapping(bytes32 => UserClaimInfo) userInfo;
    }

    // asset => claimInfo
    mapping(bytes32 => ClaimInfo) claimInfo;

    function adjustSpeed(bytes32 asset, int112 dspeed) internal {
        updateScore(GOV_USER, asset, dspeed);
    }

    function claim(bytes32 user, bytes32 asset) internal returns(uint112 claimAmount) {
        uint32 time = uint32(now % EPOCH - EPOCH);

        uint112 totalScore = getScore(GLOBAL_USER, asset, time);
        uint112 userScore = getScore(user, asset, time);
        uint112 totalGov = getScore(GOV_USER, asset, time);

        uint112 globalScoreClaimed = claimInfo[asset].globalScoreClaimed;
        uint112 totalGovClaimed = claimInfo[asset].govClaimed;
        uint112 userScoreClaimed = claimInfo[asset].userInfo[user].scoreClaimed;

        claimAmount = mul(sub(userScore, userScoreClaimed), sub(totalGov, totalGovClaimed)) / sub(totalScore, globalScoreClaimed);

        claimInfo[asset].globalScoreClaimed = add(claimInfo[asset].globalScoreClaimed , userScore);
        claimInfo[asset].userInfo[user].scoreClaimed = add(claimInfo[asset].userInfo[user].scoreClaimed, userScore);        
        claimInfo[asset].govClaimed = add(claimInfo[asset].govClaimed, claimAmount);
    }
}