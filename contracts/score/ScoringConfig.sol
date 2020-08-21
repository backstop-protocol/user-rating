pragma solidity 0.5.16;

// Other BProtocol contracts
import { IScoringMachine } from "../score/IScoringMachine.sol";

// Internal Libraries
import { Exponential } from "../lib/Exponential.sol";

/**
 * @title Scoring Configuration contract
 */
contract ScoringConfig is Exponential {

    // Minimum factor value
    uint256 constant public MIN_FACTOR = 0.01e18; // 0.01
    // Maximum factor value, scaled to 1e18
    uint256 constant public MAX_FACTOR = 2e18; // 2.0

    // Debt score factor
    uint256 public debtScoreFactor;
    // Collateral score factor
    uint256 public collScoreFactor;
    // Slashed score factor
    uint256 public slashedScoreFactor;
    // Shasher score factor
    uint256 public slasherScoreFactor;
    // Scoring Machine contract address
    IScoringMachine public scoringMachine;


    /**
     * @dev Modifier to validate the factor limit
     */
    modifier validFactor(uint256 factor) {
        require(factor >= MIN_FACTOR && factor <= MAX_FACTOR, "not-a-valid-factor");
        _;
    }

    /**
     * @dev ScoringConfig constructor, its an abstarct contract
     * @param _debtScoreFactor Debt score factor
     * @param _collScoreFactor Collateral score factor
     * @param _slashedScoreFactor Slashed score factor
     * @param _slasherScoreFactor Slasher score factor
     */
    constructor(
        uint256 _debtScoreFactor,
        uint256 _collScoreFactor,
        uint256 _slashedScoreFactor,
        uint256 _slasherScoreFactor,
        address _scoringMachine
    ) 
        internal 
    {
        require(_isValidFactor(_debtScoreFactor), "not-a-valid-debt-factor");
        require(_isValidFactor(_collScoreFactor), "not-a-valid-coll-factor");
        require(_isValidFactor(_slashedScoreFactor), "not-a-valid-slashed-factor");
        require(_isValidFactor(_slasherScoreFactor), "not-a-valid-slasher-factor");
        
        debtScoreFactor = _debtScoreFactor;
        collScoreFactor = _collScoreFactor;
        slashedScoreFactor = _slashedScoreFactor;
        slasherScoreFactor = _slasherScoreFactor;
        
        scoringMachine = IScoringMachine(_scoringMachine);
    }

    /**
     * @dev Is factor value valid under range
     * @param factor Factor value to validate
     * @return `true` when the factor is in valid range, `false` otherwise
     */
    function _isValidFactor(uint256 factor) internal pure returns (bool) {
        return factor >= MIN_FACTOR && factor <= MAX_FACTOR;
    }

    /**
     * @dev Get user's total score
     * @param user Address of the user
     * @param token Address of the token
     * @return user's total score
     */
    function getUserScore(address user, address token) external view returns (uint256) {
        // Get User score from the Scoring Machine
        uint256 uDebtScore = getUserDebtScore(user, token);
        uint256 uCollScore = getUserCollScore(user, token);
        uint256 uSlashedScore = getUserSlashedScore(user, token);
        uint256 uSlasherScore = getUserSlasherScore(user, token);

        return _calcTotalScore(uDebtScore, uCollScore, uSlashedScore, uSlasherScore);
    }

    /**
     * @dev Get global total score
     * @param token Token address
     * @return global total score
     */
    function getGlobalScore(address token) external view returns (uint256) {
        // Get Global score from the Scoring Machine
        uint256 gDebtScore = getGlobalDebtScore(token);
        uint256 gCollScore = getGlobalCollScore(token);
        uint256 gSlashedScore = getGlobalSlashedScore(token);
        uint256 gSlasherScore = getGlobalSlasherScore(token);

        return _calcTotalScore(gDebtScore, gCollScore, gSlashedScore, gSlasherScore);
    }

    /**
     * @dev Calculate total scoring using factors
     * @param debtScore User / Global debt score
     * @param collScore User / Global collaternal score
     * @param slashedScore User / Global slashed score
     * @param slasherScore User / Global slasher score
     */
    function _calcTotalScore(
        uint256 debtScore, 
        uint256 collScore, 
        uint256 slashedScore, 
        uint256 slasherScore
    ) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 fDebtScore = mulTruncate(debtScore, debtScoreFactor);
        uint256 fCollScore = mulTruncate(collScore, collScoreFactor);
        uint256 fSlashedScore = mulTruncate(slashedScore, slashedScoreFactor);
        uint256 fSlasherScore = mulTruncate(slasherScore, slasherScoreFactor);

        uint256 totalScore = add_(add_(fDebtScore, fCollScore), add_(fSlashedScore, fSlasherScore));

        return totalScore;
    }

    // Abstract functions
    // ===================

    // User Score
    // -----------
    /**
     * @dev Get user's debt score
     * @param user User address
     * @param token Token address
     * @return User's debt score
     */
    function getUserDebtScore(address user, address token) internal view returns (uint256);

    /**
     * @dev Get user's collateral score
     * @param user User address
     * @param token Token address
     * @return User's collateral score
     */
    function getUserCollScore(address user, address token) internal view returns (uint256);

    /**
     * @dev Get user's slashed score
     * @param user User address
     * @param token Token address
     * @return User's slashed score
     */
    function getUserSlashedScore(address user, address token) internal view returns (uint256);

    /**
     * @dev Get user's slasher score
     * @param user User address
     * @param token Token address
     * @return User's slasher score
     */ 
    function getUserSlasherScore(address user, address token) internal view returns (uint256);

    // Global Score
    // -------------
    /**
     * @dev Get global debt score
     * @param user User address
     * @param token Token address
     * @return Global debt score
     */
    function getGlobalDebtScore(address token) internal view returns (uint256);

    /**
     * @dev Get global collateral score
     * @param user User address
     * @param token Token address
     * @return Global collateral score
     */
    function getGlobalCollScore(address token) internal view returns (uint256);

    /**
     * @dev Get global slashed score
     * @param user User address
     * @param token Token address
     * @return Global slashed score
     */
    function getGlobalSlashedScore(address token) internal view returns (uint256);

    /**
     * @dev Get global slasher score
     * @param user User address
     * @param token Token address
     * @return Global slasher score
     */ 
    function getGlobalSlasherScore(address token) internal view returns (uint256);
}