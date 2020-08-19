pragma solidity 0.5.16;

// Other BProtocol contracts
import { IScoringMachine } from "../score/IScoringMachine.sol";

// Internal Libraries
import { Exponential } from "../lib/Exponential.sol";

// External Libraries
import { Ownable } from "../../openzeppelin-contracts/contracts/ownership/Ownable.sol";

/**
 * @title Jar Configuration contract
 */
contract JarConfig is Ownable, Exponential {

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

    enum ScoreType { Debt, Collateral, Slashed, Slasher }
    event ScoreFactorUpdated(ScoreType indexed, uint256 oldFactor, uint256 newFactor);

    /**
     * @dev Modifier to validate the factor limit
     */
    modifier validFactor(uint256 factor) {
        require(factor >= MIN_FACTOR && factor <= MAX_FACTOR, "not-a-valid-factor");
        _;
    }

    /**
     * @dev JarConfig constructor, its an abstarct contract
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
        setDebtScoreFactor(_debtScoreFactor);   
        setCollScoreFactor(_collScoreFactor);
        setSlashedScoreFactor(_slashedScoreFactor);
        setSlasherScoreFactor(_slasherScoreFactor);
        scoringMachine = IScoringMachine(_scoringMachine);
    }

    /**
     * @dev Sets new Debt score factor
     * @notice Only Owner allowed to call this function
     * @param newFactor New factor to set
     */
    function setDebtScoreFactor(uint256 newFactor) public onlyOwner validFactor(newFactor) {
        uint256 oldFactor = debtScoreFactor;
        debtScoreFactor = newFactor;
        emit ScoreFactorUpdated(ScoreType.Debt, oldFactor, newFactor);
    }

    /**
     * @dev Sets new Collateral score factor
     * @notice Only Owner allowed to call this function
     * @param newFactor New factor to set
     */
    function setCollScoreFactor(uint256 newFactor) public onlyOwner validFactor(newFactor) {
        uint256 oldFactor = collScoreFactor;
        collScoreFactor = newFactor;
        emit ScoreFactorUpdated(ScoreType.Collateral, oldFactor, newFactor);
    }

    /**
     * @dev Sets new Slashed score factor
     * @notice Only Owner allowed to call this function
     * @param newFactor New factor to set
     */
    function setSlashedScoreFactor(uint256 newFactor) public onlyOwner validFactor(newFactor) {
        uint256 oldFactor = slashedScoreFactor;
        slashedScoreFactor = newFactor;
        emit ScoreFactorUpdated(ScoreType.Slashed, oldFactor, newFactor);
    }

    /**
     * @dev Sets new Slasher score factor
     * @notice Only Owner allowed to call this function
     * @param newFactor New factor to set
     */
    function setSlasherScoreFactor(uint256 newFactor) public onlyOwner validFactor(newFactor) {
        uint256 oldFactor = slasherScoreFactor;
        slasherScoreFactor = newFactor;
        emit ScoreFactorUpdated(ScoreType.Slasher, oldFactor, newFactor);
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
     * @param token Address of the token
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
    function getUserDebtScore(address user, address token) internal view returns (uint256);
    function getUserCollScore(address user, address token) internal view returns (uint256);
    function getUserSlashedScore(address user, address token) internal view returns (uint256);
    function getUserSlasherScore(address user, address token) internal view returns (uint256);

    // Global Score
    // -------------
    function getGlobalDebtScore(address token) internal view returns (uint256);
    function getGlobalCollScore(address token) internal view returns (uint256);
    function getGlobalSlashedScore(address token) internal view returns (uint256);
    function getGlobalSlasherScore(address token) internal view returns (uint256);
}