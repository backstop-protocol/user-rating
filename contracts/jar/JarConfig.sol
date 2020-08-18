pragma solidity 0.5.16;

import { Ownable } from "../../openzeppelin-contracts/contracts/ownership/Ownable.sol";

/**
 * @title Jar Configuration contract
 */
contract JarConfig is Ownable {

    // Minimum factor value
    // TODO To Be Defined / corrected 
    uint256 constant public MIN_FACTOR = 0.1e18; // 0.1
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
     * @dev JarConfig Constructor
     * @param _debtScoreFactor Debt score factor
     * @param _collScoreFactor Collateral score factor
     * @param _slashedScoreFactor Slashed score factor
     * @param _slasherScoreFactor Slasher score factor
     */
    constructor(
        uint256 _debtScoreFactor,
        uint256 _collScoreFactor,
        uint256 _slashedScoreFactor,
        uint256 _slasherScoreFactor
    ) 
        public 
    {
        setDebtScoreFactor(_debtScoreFactor);   
        setCollScoreFactor(_collScoreFactor);
        setSlashedScoreFactor(_slashedScoreFactor);
        setSlasherScoreFactor(_slasherScoreFactor);
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


    function getUserScore(address user) external view returns (uint256) {
        // TODO get user score
        uint256 userDebtScore = 0;
        uint256 userCollScore = 0;
        uint256 userSlashedScore = 0;
        uint256 userSlasherScore = 0;

        uint256 debtScore = mulTruncate(userDebtScore, debtScoreFactor);
        uint256 collScore = mulTruncate(userCollScore, collScoreFactor);
        uint256 slashedScore = mulTruncate(userSlashedScore, slashedScoreFactor);
        uint256 slasherScore = mulTruncate(userSlasherScore, slasherScoreFactor);

        uint256 totalScore = add(add(debtScore, collScore), add(slashedScore, slasherScore));

        return totalScore;
    }

    function calculateGlobalScore() external view returns (uint256) {

    }

    // TODO Use Expnential library
    function mulTruncate(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "multiplication overflow");
        return c / 1e18;
    }

    // TODO Use Expnential library
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");

        return c;
    }
}