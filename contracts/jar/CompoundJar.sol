pragma solidity 0.5.16;

// BProtocol contracts
import { IScoringConfig } from "../score/IScoringConfig.sol";

// Internal Libraries
import { Exponential } from "../lib/Exponential.sol";

// External Libraries
import { IERC20 } from "../../openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "../../openzeppelin-contracts/contracts/token/ERC20/SafeERC20.sol";

/**
 * @title Jar contract that receive User's rewards in Compound cTokens
 */
contract CompoundJar is Exponential {

    using SafeERC20 for IERC20;

    // Round ID of the rewards distribution
    uint256 public roundId;
    // Enable withdraw of rewards after timelock
    uint256 public withdrawTimelock;
    // Connector contract address
    IConnector public connector;
    // (address => token => isUserWithdrawn) maintain the withdrawn status
    mapping(address => mapping(address => bool)) public withdrawn;
    // token => how much score was used
    mapping(address => uint) public scoreWithdrawn;

    event Withdrawn(address indexed user, address token, uint256 amount);

    /**
     * @dev Modifier to check if the withdrawal of rewards is open
     */
    modifier withdrawOpen() {
        require(_isWithdrawOpen(), "withdrawal-locked");
        _;
    }

    /**
     * @dev Constructor
     * @param _roundId Round-id for which rewards are collected in this contract
     * @param _withdrawTimelock Withdraw timelock time in future
     * @param _connector Connector contract address
     */
    constructor(
        uint256 _roundId,
        uint256 _withdrawTimelock,
        address _connector
    ) public {
        require(_withdrawTimelock > now, "incorrect-withdraw-timelock");

        roundId = _roundId;
        withdrawTimelock = _withdrawTimelock;
        connector = IConnector(_connector);
    }

    /**
     * @dev A user allowed to withdraw token rewards from Jar. A user can also withdraw on behalf
     *      other user as well.
     * @param user User's address for Compound.
     * @param cToken Address of the cToken, which user is inteded to withdraw
     */
    function withdraw(address user, address cToken) external withdrawOpen {
        bool hasWithdrawn = withdrawn[user][cToken];
        require(! hasWithdrawn, "user-withdrew-rewards-before");

        uint256 totalBalance = IERC20(cToken).balanceOf(address(this));

        uint256 userScore = _getUserScore(user, cToken);
        uint256 globalScore = _getGlobalScore(cToken);

        uint256 amount = div_(mul_(userScore, totalBalance), sub_(globalScore, scoreWithdrawn[cToken]));

        // user withdrawn token from Jar
        withdrawn[user][cToken] = true;
        scoreWithdrawn[cToken] = add_(scoreWithdrawn[cToken], userScore);

        IERC20(cToken).safeTransfer(user, amount);
        emit Withdrawn(user, cToken, amount);
    }

    /**
     * @dev Is withdrawal open
     * @return `true` when withdrawal is open, `false` otherwise
     */
    function _isWithdrawOpen() internal view returns (bool) {
        return now > withdrawTimelock;
    }

    // Connector function calls
    // =========================
    function _getUserScore(address user, address cToken) internal view returns (uint256) {
        return connector.getUserScore(user, cToken);
    }

    function _getGlobalScore(address cToken) internal view returns (uint256) {
        return connector.getGlobalScore(cToken);
    }
}

/**
 * @title Connection interface to connect to MakerDAO / Compound
 */
interface IConnector {
    function getUserScore(address user, address cToken) external view returns (uint256);
    function getGlobalScore(address cToken) external view returns (uint256);
}