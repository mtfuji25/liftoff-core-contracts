pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Roles.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";


contract GovernorRole is Initializable, Context {
    using Roles for Roles.Role;

    event GovernorAdded(address indexed account);
    event GovernorRemoved(address indexed account);

    Roles.Role private _Governors;

    function initialize(address sender) public initializer {
        if (!isGovernor(sender)) {
            _addGovernor(sender);
        }
    }

    modifier onlyGovernor() {
        require(isGovernor(_msgSender()), "GovernorRole: caller does not have the Governor role");
        _;
    }

    function isGovernor(address account) public view returns (bool) {
        return _Governors.has(account);
    }

    function addGovernor(address account) public onlyGovernor {
        _addGovernor(account);
    }

    function renounceGovernor() public {
        _removeGovernor(_msgSender());
    }

    function _addGovernor(address account) internal {
        _Governors.add(account);
        emit GovernorAdded(account);
    }

    function _removeGovernor(address account) internal {
        _Governors.remove(account);
        emit GovernorRemoved(account);
    }

    uint256[50] private ______gap;
}
