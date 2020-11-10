pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Roles.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";


contract SwapperRole is Initializable, Context {
    using Roles for Roles.Role;

    event SwapperAdded(address indexed account);
    event SwapperRemoved(address indexed account);

    Roles.Role private _swappers;

    function initialize(address sender) public initializer {
        if (!isSwapper(sender)) {
            _addSwapper(sender);
        }
    }

    modifier onlySwapper() {
        require(isSwapper(_msgSender()), "SwapperRole: caller does not have the Swapper role");
        _;
    }

    function isSwapper(address account) public view returns (bool) {
        return _swappers.has(account);
    }

    function addSwapper(address account) public onlySwapper {
        _addSwapper(account);
    }

    function renounceSwapper() public {
        _removeSwapper(_msgSender());
    }

    function _addSwapper(address account) internal {
        _swappers.add(account);
        emit SwapperAdded(account);
    }

    function _removeSwapper(address account) internal {
        _swappers.remove(account);
        emit SwapperRemoved(account);
    }

    uint256[50] private ______gap;
}
