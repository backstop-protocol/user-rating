pragma solidity 0.5.16;

import { ERC20 } from "../../openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC20Detailed } from "../../openzeppelin-contracts/contracts/token/ERC20/ERC20Detailed.sol";

contract MockERC20Detailed is ERC20, ERC20Detailed {
    constructor (string memory name, string memory symbol, uint8 decimals, uint256 tokensToMint)
        public
        ERC20Detailed(name, symbol, decimals)
    {
        // Mock contract, hence, no need for SafeMath
        uint256 tokensWithDecimals = tokensToMint * (10 ** uint256(decimals));
        _mint(msg.sender, tokensWithDecimals);
    }
}
