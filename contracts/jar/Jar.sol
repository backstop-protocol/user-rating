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
    // Is ETHExit called on MakerDAO?
    bool public ethExitCalled = false;
    // Connector contract address
    IConnector public connector; 
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
     * @dev Receive ETH sent to this contract
     */
    function () external payable {}

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
     *      other user
     * @param user CDP id in `bytes32` for MakerDAO. User's address for Compound.
     * @param token Address of the token, which user is inteded to withdraw
     */
    function withdraw(bytes32 user, address token) external {
        // Convert address to payable address
        address payable owner = address(uint160(_toUser(user)));
        _withdraw(owner, token);
    }


    /**
     * @dev Internal withdraw function to withdraw all the user's reward of a specific token
     * @param user Withdraw reward of the given user
     * @param token Withdraw all reward token balance of the user
     */
    function _withdraw(address payable user, address token) internal withdrawOpen {
        require(ethExitCalled, "eth-exit-not-called-before");

        bool hasWithdrawn = withdrawn[user][token];
        require(! hasWithdrawn, "user-withdrew-rewards-before");

        bool isEth = _isETH(token);
        uint256 totalBalance = isEth ? address(this).balance : IERC20(token).balanceOf(address(this));

        uint256 userScore = _getUserScore(user);
        uint256 globalScore = _getGlobalScore();
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

    // Connector function calls
    // =========================

    /**
     * @dev Get the total user's score from the Connector
     * @param user Address of the user
     * @return The total score of the user
     */
    function _getUserScore(address user) internal view returns (uint256) {
        return connector.getUserScore(user);
    }

    /**
     * @dev Get the total Global score from the Connector
     * @return The global total score
     */
    function _getGlobalScore() internal view returns (uint256) {
        return connector.getGlobalScore();
    }

    /**
     * @dev Convert bytes32 user to address from the Connector
     * @param user User's address in bytes32
     * @return address of the user
     */
    function _toUser(bytes32 user) internal view returns (address) {
        return connector.toUser(user);
    }

    // Delegate functions 
    // ===================
    
    /**
     * @dev Delegate call to Connector contract to convert Maker gem to WETH
     * @notice Function only be called after withdrawal is open, this is to prevent uneven 
     *         distribution of WETH (from MakerDAO) rewards to the users
     */
    function delegateEthExit() external {
        (bool success,) = address(connector).delegatecall(abi.encodeWithSignature("ethExit()"));
        require(success, "eth-exit-delegate-call-failed");
        ethExitCalled = true;
    }
}

/**
 * @title Connection interface to connect to MakerDAO / Compound
 */
interface IConnector {
    function getUserScore(address user) external view returns (uint256);
    function getGlobalScore() external view returns (uint256);
    function toUser(bytes32 user) external view returns (address);
}