pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";


contract Token is ERC20 {
    function initialize(
        uint totalSupply,
        address account
    ) public initializer {
        _mint(account, totalSupply);
    }
}
