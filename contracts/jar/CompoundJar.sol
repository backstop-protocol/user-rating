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
     * @param _withdrawTimelock Withdraw timelock time in future
     */
    constructor(uint256 _withdrawTimelock) public {
        require(_withdrawTimelock > now, "incorrect-withdraw-timelock");

        withdrawTimelock = _withdrawTimelock;
    }

    function setConnector(address _connector) external {
        require(connector == IConnector(0), "connector-already-set");
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

        uint256 userScore = connector.getUserScore(user);
        uint256 globalScore = connector.getGlobalScore();

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
}

/**
 * @title Connection interface to connect to MakerDAO / Compound
 */
interface IConnector {
    function getUserScore(address user) external view returns (uint256);
    function getGlobalScore() external view returns (uint256);
}