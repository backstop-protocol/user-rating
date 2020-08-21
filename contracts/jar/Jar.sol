pragma solidity 0.5.16;

// BProtocol contracts
import { IScoringConfig } from "../score/IScoringConfig.sol";

// Internal Libraries
import { Exponential } from "../lib/Exponential.sol";

// External Libraries
import { IERC20 } from "../../openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title Jar contract that receive User's rewards in ETH / ERC20
 */
contract Jar is Exponential {

    address internal constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Round ID of the rewards distribution
    uint256 public roundId;
    // Enable withdraw of rewards after timelock
    uint256 public withdrawTimelock;
    // Scoring Config contract
    IScoringConfig public scoringConfig;
    // ETHExit contract address
    address public ethExit;
    // (user => token => isUserWithdrawn) maintain the withdrawn status
    mapping(address => mapping(address => bool)) withdrawn;

    event Withdrawn(address indexed user, address token, uint256 amount);

    /**
     * @dev Modifier to check if the withdrawal of rewards is open
     */
    modifier withdrawOpen() {
        require(now > withdrawTimelock, "withdrawal-locked");
        _;
    }

    /**
     * @dev Constructor
     * @param _roundId Round-id for which rewards are collected in this contract
     * @param _withdrawTimelock Withdraw timelock time in future
     * @param _scoringConfig Address of ScoringConfig contract
     * @param _ethExit ETHExit contract address
     */
    constructor(
        uint256 _roundId,
        uint256 _withdrawTimelock, 
        address _scoringConfig,
        address _ethExit
    ) public {
        require(_withdrawTimelock > now, "incorrect-withdraw-timelock");

        roundId = _roundId;
        withdrawTimelock = _withdrawTimelock;
        scoringConfig = IScoringConfig(_scoringConfig);
        ethExit = _ethExit;
    }

    /**
     * @dev msg.sender withdraw all his rewards of the given token
     * @param token Token address to collect all rewards of that token
     */
    function withdraw(address token) external {
        _withdraw(msg.sender, token);
    }

    /**
     * @dev Withdraw all rewards of a given token on behalf of a user
     * @param user User's EOA for which rewards are withdrawn
     * @param token Token address to collect all rewards of that token
     */
    function withdrawOnBehalfOf(address payable user, address token) external {
        _withdraw(user, token);
    }

    /**
     * @dev Internal withdraw function to withdraw all the user's reward of a specific token
     * @param user Withdraw reward of the given user
     * @param token Withdraw all reward token balance of the user
     */
    function _withdraw(address payable user, address token) internal withdrawOpen {
        bool hasWithdrawn = withdrawn[user][token];
        require(! hasWithdrawn, "user-withdrew-rewards-before");

        bool isEth = _isETH(token);
        uint256 totalBalance = isEth ? address(this).balance : IERC20(token).balanceOf(address(this));

        // In case `delegateEthExit` is not called and a user is withdrawing WETH, this
        // check would prevent him to withdraw zero WETH
        require(totalBalance > 0, "no-rewards-for-token");

        uint256 userScore = scoringConfig.getUserScore(user, token);
        uint256 globalScore = scoringConfig.getGlobalScore(token);
        uint256 userPortion = div_(mul_(userScore, expScale), globalScore);

        uint256 amount = mulTruncate(totalBalance, userPortion);

        // user withdrawn token from Jar
        withdrawn[user][token] = true;

        // send amount to the user
        if(isEth) {
            user.transfer(amount);
        } else {
            require(IERC20(token).transfer(user, amount), "transfer-failed");
        }

        emit Withdrawn(user, token, amount);
    }

    /**
     * @dev Is token address is ETH_ADD address
     * @param token ERC20 token address / ETH_ADD address to check
     * @return `true` when token is an ETH_ADD, `false` otherwise
     */
    function _isETH(address token) internal pure returns (bool) {
        return token == ETH_ADDR;
    }

    /**
     * @dev Delegate call to ETHExit contract to convert Maker gem to WETH
     * @notice Function only be called after withdrawal is open, this is to prevent uneven 
     *         distribution of WETH (from MakerDAO) rewards to the users
     */
    function delegateEthExit() external withdrawOpen {
        (bool success,) = ethExit.delegatecall(abi.encodeWithSignature("ethExit()"));
        require(success, "eth-exit-delegate-call-failed");
    }

    /**
     * @dev Receive ETH sent to this contract
     */
    function () external payable {}
}