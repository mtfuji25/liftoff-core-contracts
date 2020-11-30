pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./SimpleToken.sol";
import "./LiftoffEngine.sol";

contract LiftoffRegistration is Initializable, Ownable {
    struct ipfsProjectHash {
        string ipfsProjectJsonHash;
        string ipfsProjectLogoHash;
        string ipfsProjectOpenGraphHash;
    }

    address public liftoffEngine;
    uint public minLaunchTime;
    uint public maxLaunchTime;
    uint public halvingPeriod;

    mapping(address => ipfsProjectHash) tokenProjects;
    
    address[] public tokenAddress;
    uint public tokenAddressLength;

    function initialize(
        address _owner
    ) public initializer {
        Ownable.initialize(_owner);
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

        LiftoffEngine instance = LiftoffEngine(liftoffEngine);
        instance.launchToken(address(token), msg.sender, token.totalSupply(), halvingPeriod, launchTime);
    }

    function setLaunchTimeDelta(uint _min, uint _max) external onlyOwner {
        minLaunchTime = _min;
        maxLaunchTime = _max;
    }

    function setHalvingPeriod(uint _period) external onlyOwner {
        halvingPeriod = _period;
    }

    function setLiftoffEngine(address _liftoffEngine) external onlyOwner {
        liftoffEngine = _liftoffEngine;
    }
}