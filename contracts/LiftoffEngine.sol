pragma solidity 0.5.16;

import "./interfaces/ILiftoffSwap.sol";
import "./library/BasisPoints.sol";
import "./uniswapV2Periphery/interfaces/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract LiftoffEngine is Initializable, Ownable, ReentrancyGuard, Pausable {
  using BasisPoints for uint;
  using SafeMath for uint;
  using Math for uint;

  struct Checkpoint {
      uint128 fromBlock;
      uint128 value;
  }

  struct Token {
    uint totalBalance;
    uint halvingPeriod;
    uint nextHalving;
    uint emissionRate;
    uint startTime;
    uint rewardPerWeiStored;
    uint lastUpdate;
    uint unclaimedTokens;
    bool isSparked;
    IERC20 deployed;
    address payable projectDev;
    mapping(address => Ignitor) ignitors;
    Checkpoint[] totalBalanceHistory;
  }
  
  struct Ignitor {
    uint balance;
    uint rewards;
    uint rewardPerWeiPaid;
    Checkpoint[] balanceHistory;
  }

  mapping(address => Token) public tokens;

  address public liftoffLauncher;
  address payable public lidTreasury;
  ILiftoffSwap public swapper;
  uint public projectDevEthBP;
  uint public lidEthBP;
  uint public projectDevTokenBP;
  uint public lidTokenBP;
  uint public sparkPeriod;

  function initialize(
    address _liftoffLauncher,
    address payable _lidTreasury,
    ILiftoffSwap _swapper,
    uint _projectDevEthBP,
    uint _lidEthBP,
    uint _projectDevTokenBP,
    uint _lidTokenBP,
    uint _sparkPeriod,
    address _liftoffGovernance
  ) external initializer {
    Ownable.initialize(_liftoffGovernance);
    Pausable.initialize(_liftoffGovernance);
    ReentrancyGuard.initialize();
    liftoffLauncher = _liftoffLauncher;
    lidTreasury = _lidTreasury;
    swapper = _swapper;
    projectDevEthBP = _projectDevEthBP;
    lidEthBP = _lidEthBP;
    projectDevTokenBP = _projectDevTokenBP;
    lidTokenBP = _lidTokenBP;
    sparkPeriod = _sparkPeriod;
  }

  function setGovernanceProperties(
    address _liftoffLauncher,
    address payable _lidTreasury,
    ILiftoffSwap _swapper,
    uint _projectDevEthBP,
    uint _lidEthBP,
    uint _projectDevTokenBP,
    uint _lidTokenBP
  ) external onlyOwner {
    liftoffLauncher = _liftoffLauncher;
    lidTreasury = _lidTreasury;
    swapper = _swapper;
    projectDevEthBP = _projectDevEthBP;
    lidEthBP = _lidEthBP;
    projectDevTokenBP = _projectDevTokenBP;
    lidTokenBP = _lidTokenBP;
  }

  function launchToken(
    address _token,
    address payable _projectDev,
    uint _amount,
    uint _halvingPeriod,
    uint _startTime
  ) external whenNotPaused {
    require(msg.sender == liftoffLauncher, "Sender must be launcher");
    require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), "Transfer Failed");
    Token storage token = tokens[_token];
    require(token.startTime == 0, "Token already launched");
    token.projectDev = _projectDev;
    token.halvingPeriod = _halvingPeriod;
    token.startTime = _startTime;
    token.deployed = IERC20(_token);
    token.nextHalving = _startTime.add(sparkPeriod);
  }

  function ignite(address _token) external payable nonReentrant whenNotPaused {
    address sender = msg.sender;
    uint value = msg.value;
    Token storage token = tokens[_token];
    Ignitor storage ignitor = token.ignitors[sender];
    require(token.startTime <= block.timestamp,"Token not yet available");

    //During the spark period, no rewards are earned
    if(token.isSparked) {
      _updateReward(token, ignitor);
      _applyHalving(token);
    }

    uint oldTotalBalance = token.totalBalance;
    token.totalBalance = oldTotalBalance.add(value);
    uint oldIgnitorBalance = ignitor.balance;
    ignitor.balance = oldIgnitorBalance.add(value);

    _updateCheckpointValueAtNow(
      token.totalBalanceHistory,
      oldTotalBalance,
      token.totalBalance
    );
    _updateCheckpointValueAtNow(
      token.totalBalanceHistory,
      oldIgnitorBalance,
      ignitor.balance
    );

    uint projectDevEth = value.mulBP(projectDevEthBP);
    uint lidEth = value.mulBP(lidEthBP);

    require(token.projectDev.send(projectDevEth), "Project dev send failed");
    require(lidTreasury.send(lidEth), "Lid send failed");
    swapper.acceptIgnite.value(value.sub(projectDevEth).sub(lidEth))(_token);
  }

  function claimReward(address _token) external whenNotPaused {
    address sender = msg.sender;
    Token storage token = tokens[_token];
    Ignitor storage ignitor = token.ignitors[sender];
    require(token.isSparked, "No rewards claimable before spark");
    _updateReward(token, ignitor);
    _applyHalving(token);
    uint reward = _earned(token, ignitor);
    if (reward > 0) {
      require(token.unclaimedTokens >= reward,"TEMP: uncliamed less than reward");
      ignitor.rewards = 0;
      token.unclaimedTokens = token.unclaimedTokens.sub(reward);
      uint projectDevTokens = reward.mulBP(projectDevTokenBP);
      uint lidTokens = reward.mulBP(lidTokenBP);

      require(token.deployed.transfer(token.projectDev, projectDevTokens),"Transfer failed");
      require(token.deployed.transfer(lidTreasury, lidTokens),"Transfer failed");
      require(token.deployed.transfer(sender, reward.sub(projectDevTokens).sub(lidTokens)),"Transfer failed");
    }
  }

  function spark(address _token) external whenNotPaused {
    Token storage token = tokens[_token];
    require(token.startTime.add(sparkPeriod) <= now, "Must be after sparkPeriod ends");
    require(!token.isSparked, "Token already sparked");
    token.isSparked = true;
    swapper.acceptSpark(_token);
    //The first halving is at the spark time
    //Which is where earnings start
    //So the rewardPerWei stored should be calculated from this point forward
    token.lastUpdate = token.nextHalving;
    _applyHalving(token);
    token.rewardPerWeiStored = _rewardPerWei(token);
    token.lastUpdate = _lastTimeRewardApplicable(token);
  }

  function mutiny(address _token, address payable _newProjectDev) external onlyOwner whenNotPaused {
    Token storage token = tokens[_token];
    token.projectDev = _newProjectDev;
  }

  function getEarned(address _token, address _ignitor) external view whenNotPaused returns (uint) {
    Token storage token = tokens[_token];
    Ignitor storage ignitor = token.ignitors[_ignitor];
    return _earned(token, ignitor);
  }

  function getToken(address _token) external view returns (
    uint totalIgnited,
    uint halvingPeriod,
    uint nextHalving,
    uint emissionRate,
    uint startTime,
    uint rewardPerWeiStored,
    uint lastUpdate,
    uint unclaimedTokens,
    bool isSparked,
    IERC20 deployed,
    address payable projectDev
  ) {
    Token storage token = tokens[_token];
    return (
      token.totalBalance,
      token.halvingPeriod,
      token.nextHalving,
      token.emissionRate,
      token.startTime,
      token.rewardPerWeiStored,
      token.lastUpdate,
      token.unclaimedTokens,
      token.isSparked,
      token.deployed,
      token.projectDev
    );
  }

  function getIgnitor(address _token, address _ignitor) external view returns (
    uint balance,
    uint rewards,
    uint rewardPerWeiPaid
  ) {
    Token storage token = tokens[_token];
    Ignitor storage ignitor = token.ignitors[_ignitor];
    return (
      ignitor.balance,
      ignitor.rewards,
      ignitor.rewardPerWeiPaid
    );
  }

  function ignitorBalanceAt(address _token, address _ignitor, uint _blockNumber) external view returns(uint) {
    Token storage token = tokens[_token];
    Ignitor storage ignitor = token.ignitors[_ignitor];
    if (ignitor.balanceHistory.length == 0) {
      return ignitor.balance;
    } else {
      return _getCheckpointValueAt(
        ignitor.balanceHistory,
        _blockNumber
      );
    }
  }

  function totalIgnitedAt(address _token,  uint _blockNumber) external view returns(uint) {
    Token storage token = tokens[_token];
    if (token.totalBalanceHistory.length == 0) {
      return token.totalBalance;
    } else {
      return _getCheckpointValueAt(
        token.totalBalanceHistory,
        _blockNumber
      );
    }
  }

  function _earned(Token storage token, Ignitor storage ignitor) internal view returns (uint256) {
    return
      ignitor.balance
        .mul(_rewardPerWei(token).sub(ignitor.rewardPerWeiPaid))
        .div(1e18)
        .add(ignitor.rewards);
  }

  function _rewardPerWei(Token storage token) internal view returns (uint) {
    if(token.emissionRate == 0) return 0;
    return 
      token.rewardPerWeiStored.add(
        _lastTimeRewardApplicable(token)
          .sub(token.lastUpdate)
          .mul(token.emissionRate)
          .mul(1e18)
          .div(token.totalBalance)
      );
  }

  function _lastTimeRewardApplicable(Token storage token) internal view returns (uint256) {
    return Math.min(block.timestamp, token.nextHalving);
  }

  function _updateReward(Token storage token, Ignitor storage ignitor) internal {
    token.rewardPerWeiStored = _rewardPerWei(token);
    token.lastUpdate = _lastTimeRewardApplicable(token);
    ignitor.rewards = _earned(token, ignitor);
    ignitor.rewardPerWeiPaid = token.rewardPerWeiStored;
  }

  function _applyHalving(Token storage token) internal {
    if (now >= token.nextHalving) {
      uint period = token.halvingPeriod;
      uint amount = token.deployed
        .balanceOf(address(this)).sub(
        token.unclaimedTokens
      ).mulBP(5000);
      token.emissionRate = amount.div(period);
      token.nextHalving = token.nextHalving.add(period);
      token.unclaimedTokens = token.unclaimedTokens.add(amount);
    }
  }
  
  function _getCheckpointValueAt(Checkpoint[] storage checkpoints, uint _block) view internal returns (uint) {
    // This case should be handled by caller
    if (checkpoints.length == 0)
      return 0;

    // Use the latest checkpoint
    if (_block >= checkpoints[checkpoints.length-1].fromBlock)
      return checkpoints[checkpoints.length-1].value;

    // Use the oldest checkpoint
    if (_block < checkpoints[0].fromBlock)
      return checkpoints[0].value;

    // Binary search of the value in the array
    uint min = 0;
    uint max = checkpoints.length-1;
    while (max > min) {
      uint mid = (max + min + 1) / 2;
      if (checkpoints[mid].fromBlock<=_block) {
        min = mid;
      } else {
        max = mid-1;
      }
    }
    return checkpoints[min].value;
  }

  function _updateCheckpointValueAtNow(
    Checkpoint[] storage checkpoints,
    uint _oldValue,
    uint _value
  ) internal {
    require(_value <= uint128(-1));
    require(_oldValue <= uint128(-1));

    if (checkpoints.length == 0) {
      Checkpoint storage genesis = checkpoints[checkpoints.length++];
      genesis.fromBlock = uint128(block.number - 1);
      genesis.value = uint128(_oldValue);
    }

    if (checkpoints[checkpoints.length - 1].fromBlock < block.number) {
      Checkpoint storage newCheckPoint = checkpoints[checkpoints.length++];
      newCheckPoint.fromBlock = uint128(block.number);
      newCheckPoint.value = uint128(_value);
    } else {
      Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length - 1];
      oldCheckPoint.value = uint128(_value);
    }
  }
}