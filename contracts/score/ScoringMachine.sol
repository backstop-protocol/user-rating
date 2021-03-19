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
    mapping(bytes32 => mapping(bytes32 => User)) public userScore;

    bytes32 constant public GLOBAL_USER = bytes32(0x0);

    uint public start; // start time of the campaign;
    uint constant public EPOCH = 1 days; // TODO - decide

    function spin() external onlyOwner { // start a new round
        start = now;
    }

    function getLatestScoreIndex(
        bytes32 user,
        bytes32 asset
    ) internal view returns(uint latest, uint[3] memory last) {
        User memory user = userScore[user][asset];
        uint last0 = user.scores[0].last;
        uint last1 = user.scores[1].last;
        uint last2 = user.scores[2].last;

        last[0] = last0; last[1] = last1; last[2] = last2;

        if((last0 > last1) && (last0 > last2)) latest = 0;
        else if(last1 > last2) latest = 1;
        else latest = 2;
    }

    function updateAssetScore(bytes32 user, bytes32 asset, int dbalance) internal {
        (uint latest, uint[3] memory last) = getLatestScoreIndex(user, asset);
        uint time = now;

        uint dtime = sub(time, last[latest] == 0 ? start : last[latest]);
        if(dtime >= EPOCH) {
            latest = (latest + 1) % 3;
        }
        
        AssetScore storage score = userScore[user][asset].scores[latest];

        score.score = uint112(add(score.score, mul(score.balance, dtime)));
        score.balance = uint112(add(score.balance, dbalance));
        
        score.last = uint32(time);
    }

    function slashAssetScore(bytes32 user, bytes32 asset, int dbalance) internal {
        (uint latest, uint[3] memory last) = getLatestScoreIndex(user, asset);
        uint time = now;
        
        for(uint i = 0 ; i < 3 ; i++) {
            uint index = (latest + 2 + i) % 3;
            AssetScore storage score = userScore[user][asset].scores[index];
            score.balance = uint112(add(score.balance, dbalance));
            
            if(add(last[index], 2 * EPOCH) >= time) {
                score.score = uint112(add(score.score, -mul(uint(dbalance), EPOCH)));
            }
        }
    }

    function updateScore(bytes32 user, bytes32 asset, int dbalance) internal {
        updateAssetScore(user, asset, dbalance);
        updateAssetScore(GLOBAL_USER, asset, dbalance);
    }

    function slashScore(bytes32 user, bytes32 asset, int dbalance) internal {
        slashAssetScore(user, asset, dbalance);
        slashAssetScore(GLOBAL_USER, asset, dbalance);
    }    

    function getScore(bytes32 user, bytes32 asset, uint time) public view returns(uint score) {
        (uint latest, uint[3] memory last) = getLatestScoreIndex(user, asset);
        uint index = 0;
        for(uint i = 0 ; i < 3 ; i++) {
            index = (latest + i) % 3;
            if(add(last[index], EPOCH) >= time) break;
        }

        AssetScore storage score = userScore[user][asset].scores[index];
        uint dtime = sub(time, last[index]);
        return add(score.score, mul(score.balance, dtime));
    }

    function getCurrentBalance(bytes32 user, bytes32 asset) public view returns(uint balance) {
        (uint latest,) = getLatestScoreIndex(user, asset);
        balance = userScore[user][asset].scores[latest].balance;
    }

    // Math functions without errors
    // ==============================
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        if(!(z >= x)) return 0;

        return z;
    }

    function add(uint x, int y) internal pure returns (uint z) {
        z = x + uint(y);
        if(!(y >= 0 || z <= x)) return 0;
        if(!(y <= 0 || z >= x)) return 0;

        return z;
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        if(!(y <= x)) return 0;
        z = x - y;

        return z;
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        if (x == 0) return 0;

        z = x * y;
        if(!(z / x == y)) return 0;

        return z;
    }
}

contract ClaimMachine is ScoringMachine {
    bytes32 constant public INDEX_USER = bytes32(uint(0x1));

    struct UserIndex {
        uint112 lastIndex;
        uint32  lastClaimTime;
    }

    // user => asset > UserIndex
    mapping(bytes32 => mapping(bytes32 => UserIndex)) userIndex;

    function adjustSpeed(bytes32 asset, int dspeed) internal {
        updateScore(INDEX_USER, asset, dspeed);
    }

    function claim(bytes32 user, bytes32 asset) internal returns(uint claimAmount) {
        uint time = now % EPOCH - EPOCH;

        uint totalScore = getScore(GLOBAL_USER, asset, time);
        uint userScore = getScore(user, asset, time);

        uint globalIndex = getScore(INDEX_USER, asset, time);

        UserIndex storage index = userIndex[user][asset];
        uint claimAmount = mul(userScore, mul(sub(globalIndex, index.lastIndex), sub(time, index.lastClaimTime))) / totalScore;

        index.lastIndex = uint112(globalIndex);
        index.lastClaimTime = uint32(time);
    }
}