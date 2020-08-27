pragma solidity 0.5.16;

import { ERC20 } from "../../openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC20Detailed } from "../../openzeppelin-contracts/contracts/token/ERC20/ERC20Detailed.sol";

contract ERC20DetailedMock is ERC20, ERC20Detailed {
    constructor (string memory name, string memory symbol, uint8 decimals)
        public
        ERC20Detailed(name, symbol, decimals)
    {
        // solhint-disable-previous-line no-empty-blocks
    }
}
