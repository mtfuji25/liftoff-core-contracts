pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";

contract SimpleToken is ERC20, ERC20Detailed {
    constructor() public {
        ERC20Detailed.initialize("Gold", "GLD", 18);
        _mint(msg.sender, 100000 * (10 ** uint256(decimals())));
    }
}