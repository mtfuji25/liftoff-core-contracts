pragma solidity 0.5.16;

import "./SimpleToken.sol";
import "./LiftoffEngine.sol";

contract LiftoffRegistration is LiftoffEngine {
    struct ipfsProjectHash {
        string ipfsProjectJsonHash;
        string ipfsProjectLogoHash;
        string ipfsProjectOpenGraphHash;
    }

    uint public minLaunchTime;
    uint public maxLaunchTime;
    uint public halvingPeriod;

    mapping(address => ipfsProjectHash) tokenProjects;
    
    address[] public tokenAddress;
    uint public tokenAddressLength;

    function initialize(
        uint _minLaunchTime,
        uint _maxLaunchTime,
        uint _halvingPeriod,
        address _owner
    ) public initializer {
        Ownable.initialize(_owner);
        minLaunchTime = _minLaunchTime;
        maxLaunchTime = _maxLaunchTime;
        halvingPeriod = _halvingPeriod;
    }

    function registerProject(
        string calldata ipfsProjectJsonHash,
        string calldata ipfsProjectLogoHash,
        string calldata ipfsProjectOpenGraphHash,
        uint launchTime
    ) external {
        require(launchTime >= block.timestamp + minLaunchTime, "Not allowed to launch before minLaunchTime");
        require(launchTime <= block.timestamp + maxLaunchTime, "Not allowed to launch after maxLaunchTime");
        
        ERC20Detailed token = new SimpleToken();
        
        ipfsProjectHash storage project = tokenProjects[address(token)];
        project.ipfsProjectJsonHash = ipfsProjectJsonHash;
        project.ipfsProjectLogoHash = ipfsProjectLogoHash;
        project.ipfsProjectOpenGraphHash = ipfsProjectOpenGraphHash;

        tokenAddress.push(address(token));
        tokenAddressLength = tokenAddress.length;

        LiftoffEngine.launchToken(address(token), msg.sender, token.totalSupply(), halvingPeriod, launchTime);
    }

    function setLaunchTimeDelta(uint _min, uint _max) external onlyOwner {
        minLaunchTime = _min;
        maxLaunchTime = _max;
    }

    function setHalvingPeriod(uint _period) external onlyOwner {
        halvingPeriod = _period;
    }
}