pragma solidity 0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "./LiftoffEngine.sol";

contract SimpleToken is Initializable, ERC20, ERC20Detailed {
    function initialize(address sender) public initializer {
        ERC20Detailed.initialize("Token", "TKN", 18);
        _mint(sender, 100000 * (10 ** uint256(decimals())));
    }
}

contract LiftoffRegistration is LiftoffEngine {
    struct ipfsProjectHash {
        string ipfsProjectJsonHash;
        string ipfsProjectLogoHash;
        string ipfsProjectOpenGraphHash;
    }

    mapping(address => ipfsProjectHash) ipfsProjects;
    
    address[] public tokenAddress;
    uint public tokenAddressLength;

    function registerProject(
        string calldata ipfsProjectJsonHash,
        string calldata ipfsProjectLogoHash,
        string calldata ipfsProjectOpenGraphHash,
        uint launchTime
    ) external {
        require(launchTime >= block.timestamp + 1 days,"launchTime is at least 24 hrs in the future");
        require(launchTime <= block.timestamp + 360 days,"launchTime is no more than 360 days in the future");
        
        ERC20Detailed token = new SimpleToken();
        token.initialize(msg.sender);
        
        ipfsProjectHash storage project = ipfsProjects[address(token)];
        project.ipfsProjectJsonHash = ipfsProjectJsonHash;
        project.ipfsProjectLogoHash = ipfsProjectJsonHash;
        project.ipfsProjectOpenGraphHash = ipfsProjectOpenGraphHash;

        tokenAddress[tokenAddress.length] = address(token);
        tokenAddressLength = tokenAddress.length;

        LiftoffEngine.launchToken(address(token), msg.sender, token.totalSupply(), 7 days, launchTime);
    }
}