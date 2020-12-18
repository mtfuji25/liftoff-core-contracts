pragma solidity =0.6.6;

import "./interfaces/ILiftoffEngine.sol";
import "./interfaces/ILiftoffSettings.sol";
import "./interfaces/ILiftoffInsurance.sol";
import "./xlock/IXeth.sol";
import "./xlock/IXlocker.sol";
import "./library/BasisPoints.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract LiftoffEngine is
  ILiftoffEngine,
  Initializable,
  OwnableUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using BasisPoints for uint;
  using SafeMathUpgradeable for uint;
  using MathUpgradeable for uint;

  struct TokenSale {
    uint startTime;
    uint endTime;
    uint softCap;
    uint hardCap;
    uint totalIgnited;
    uint totalSupply;
    uint rewardSupply;
    address projectDev;
    address deployed;
    bool isSparked;
    string name;
    string symbol;
    mapping(address => Ignitor) ignitors;
  }

  struct Ignitor {
    uint ignited;
    bool hasClaimed;
    bool hasRefunded;
  }
  
  ILiftoffSettings public liftoffSettings;

  TokenSale[] public tokens;
  uint public totalTokenSales;

  function initialize(
    ILiftoffSettings _liftoffSettings
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    PausableUpgradeable.__Pausable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    liftoffSettings = _liftoffSettings;
  }

  function setLiftoffSettings(
    ILiftoffSettings _liftoffSettings
  ) public onlyOwner {
    liftoffSettings = _liftoffSettings;
  }

  function launchToken(
    uint _startTime,
    uint _endTime,
    uint _softCap,
    uint _hardCap,
    uint _totalSupply,
    string calldata _name,
    string calldata _symbol,
    address _projectDev
  ) external override whenNotPaused returns (uint tokenId) {
    require(msg.sender == liftoffSettings.getLiftoffLauncher(), "Sender must be launcher");
    require(_endTime > _startTime, "Must end after start");
    require(_startTime > now, "Must start in the future");
    require(_hardCap >= _softCap, "Hardcap must be at least softCap");

    tokenId = totalTokenSales;

    tokens[tokenId] = TokenSale({
      startTime: _startTime,
      endTime: _endTime,
      softCap: _softCap,
      hardCap: _hardCap,
      totalIgnited: 0,
      totalSupply: _totalSupply,
      rewardSupply: 0,
      projectDev: _projectDev,
      deployed: address(0),
      name: _name,
      symbol: _symbol,
      isSparked: false
    });

    totalTokenSales++;
  }

  function igniteEth(uint _tokenSaleId) external override payable whenNotPaused {
    TokenSale storage tokenSale = tokens[_tokenSaleId];
    require(
      isIgniting(tokenSale.startTime, tokenSale.endTime, tokenSale.totalIgnited, tokenSale.hardCap),
      "Not igniting."
    );
    uint toIgnite = getAmountToIgnite(msg.value, tokenSale.hardCap, tokenSale.totalIgnited);

    IXeth(liftoffSettings.getXEth()).deposit{value:toIgnite}();
    _addIgnite(tokenSale, msg.sender, toIgnite);

    msg.sender.transfer(msg.value.sub(toIgnite));
  }

  function ignite(uint _tokenSaleId, address _for, uint _amountXEth) external override whenNotPaused {
    TokenSale storage tokenSale = tokens[_tokenSaleId];
    require(
      isIgniting(tokenSale.startTime, tokenSale.endTime, tokenSale.totalIgnited, tokenSale.hardCap),
      "Not igniting."
    );
    uint toIgnite = getAmountToIgnite(_amountXEth, tokenSale.hardCap, tokenSale.totalIgnited);

    require(IXeth(liftoffSettings.getXEth()).transferFrom(msg.sender, address(this), toIgnite), "Transfer Failed");
    _addIgnite(tokenSale, _for, toIgnite);
  }

  function claimReward(uint _tokenSaleId, address _for) external override whenNotPaused {
    TokenSale storage tokenSale = tokens[_tokenSaleId];
    Ignitor storage ignitor = tokenSale.ignitors[_for];

    require(tokenSale.isSparked, "Token must have been sparked.");
    require(!ignitor.hasClaimed, "Ignitor has already claimed");

    uint reward = getReward(ignitor.ignited, tokenSale.rewardSupply, tokenSale.totalIgnited);
    require(reward > 0, "Must have some rewards to claim.");
    
    ignitor.hasClaimed = true;
    require(IERC20(tokenSale.deployed).transfer(_for, reward), "Transfer failed");
  }

  function spark(uint _tokenSaleId) external override whenNotPaused {
    TokenSale storage tokenSale = tokens[_tokenSaleId];

    require(isSparkReady(
        tokenSale.endTime,
        tokenSale.totalIgnited,
        tokenSale.hardCap,
        tokenSale.softCap,
        tokenSale.isSparked
      ),
      "Not spark ready"
    );
    
    tokenSale.isSparked = true;

    uint xEthBuy = _deployViaXLock(tokenSale);
    _allocateTokensPostDeploy(tokenSale);
    _insuranceRegistration(tokenSale, _tokenSaleId, xEthBuy);
  }

  function claimRefund(uint _tokenSaleId, address payable _for) external override nonReentrant whenNotPaused {
    TokenSale storage tokenSale = tokens[_tokenSaleId];
    Ignitor storage ignitor = tokenSale.ignitors[_for];

    require(isRefunding(
        tokenSale.endTime,
        tokenSale.softCap,
        tokenSale.totalIgnited
      ),
      "Not refunding"
    );

    require(!ignitor.hasRefunded, "Ignitor has already refunded");
    ignitor.hasRefunded = true;

    IXeth(liftoffSettings.getXEth()).transfer(_for, ignitor.ignited);
  }

  function getTokenSale(uint _tokenSaleId) external override view returns (
    uint startTime,
    uint endTime,
    uint softCap,
    uint hardCap,
    uint totalIgnited,
    uint totalSupply,
    uint rewardSupply,
    address projectDev,
    address deployed,
    bool isSparked
  ){
    TokenSale storage tokenSale = tokens[_tokenSaleId];

    startTime = tokenSale.startTime;
    endTime = tokenSale.endTime;
    softCap = tokenSale.softCap;
    hardCap = tokenSale.hardCap;
    totalIgnited = tokenSale.totalIgnited;
    totalSupply = tokenSale.totalSupply;
    rewardSupply = tokenSale.rewardSupply;
    projectDev = tokenSale.projectDev;
    deployed = tokenSale.deployed;
    isSparked = tokenSale.isSparked;
  }

  function getTokenSaleForInsurance(uint _tokenSaleId) external override view returns (
    uint totalIgnited,
    uint rewardSupply,
    address projectDev,
    address deployed
  ) {
    TokenSale storage tokenSale = tokens[_tokenSaleId];
    totalIgnited = tokenSale.totalIgnited;
    rewardSupply = tokenSale.rewardSupply;
    projectDev = tokenSale.projectDev;
    deployed = tokenSale.deployed;
  }

  function isSparkReady(
    uint endTime,
    uint totalIgnited,
    uint hardCap,
    uint softCap,
    bool isSparked
  ) public override view returns (bool) {
    if(
      (now <= endTime && totalIgnited < hardCap) ||
      totalIgnited < softCap ||
      isSparked
    ) {
      return false;
    } else {
      return true;
    }
  }

  function isIgniting(
    uint startTime,
    uint endTime,
    uint totalIgnited,
    uint hardCap
  ) public override view returns (bool) {
    if(
      now < startTime ||
      now > endTime ||
      totalIgnited >= hardCap
    ){
      return false;
    } else {
      return true;
    }    
  }

  function isRefunding(
    uint endTime,
    uint softCap,
    uint totalIgnited
  ) public override view returns (bool) {
    if(
      totalIgnited >= softCap ||
      now <= endTime
    ) {
      return false;
    } else {
      return true;
    }
  }

  function getReward(
    uint ignited,
    uint rewardSupply,
    uint totalIgnited
  ) public override pure returns (uint reward) {
    return ignited.mul(rewardSupply).div(totalIgnited);
  }

  function getAmountToIgnite(uint amountXEth, uint hardCap, uint totalIgnited) public pure returns (uint toIgnite) {
    uint maxIgnite = hardCap.sub(totalIgnited);

    if(maxIgnite < toIgnite) { //Can only ignite up to the hardcap.
      toIgnite = maxIgnite;
    } else {
      toIgnite = amountXEth;
    }
  }

  function _deployViaXLock(TokenSale storage tokenSale) internal returns (uint xEthBuy) {
    uint xEthLocked = tokenSale.totalIgnited.mulBP(
      liftoffSettings.getEthXLockBP()
    );
    xEthBuy = tokenSale.totalIgnited.mulBP(
      liftoffSettings.getEthBuyBP()
    );

    (address deployed, address _) = 
    IXlocker(liftoffSettings.getXLocker()).launchERC20(
      tokenSale.name,
      tokenSale.symbol,
      tokenSale.totalSupply,
      xEthLocked
    );

    address[] memory path = new address[](2);
    path[0] = liftoffSettings.getXEth();
    path[1] = deployed;

    IUniswapV2Router02(liftoffSettings.getUniswapRouter())
    .swapExactTokensForTokens(
        xEthBuy,
        0,
        path,
        address(this),
        now
    );

    tokenSale.deployed = deployed;

    return xEthBuy;
  }

  function _allocateTokensPostDeploy(TokenSale storage tokenSale) internal {
    IERC20 deployed = IERC20(tokenSale.deployed);
    uint balance = deployed.balanceOf(address(this));
    tokenSale.rewardSupply = balance.mulBP(
      liftoffSettings.getTokenUserBP()
    );
  }

  function _insuranceRegistration(TokenSale storage tokenSale, uint _tokenSaleId, uint _xEthBuy) internal {
    IERC20 deployed = IERC20(tokenSale.deployed);
    uint toInsurance = deployed.balanceOf(address(this)).sub(tokenSale.rewardSupply);
    address liftoffInsurance = liftoffSettings.getLiftoffInsurance();
    deployed.transfer(liftoffInsurance, toInsurance);
    IXeth(liftoffSettings.getXEth()).transfer(liftoffInsurance, tokenSale.totalIgnited.sub(_xEthBuy));
    
    ILiftoffInsurance(liftoffInsurance)
    .register(_tokenSaleId);
  }

  function _addIgnite(TokenSale storage tokenSale, address _for, uint toIgnite) internal {
    Ignitor storage ignitor = tokenSale.ignitors[_for];
    ignitor.ignited = ignitor.ignited.add(toIgnite);
    tokenSale.totalIgnited = tokenSale.totalIgnited.add(toIgnite);
  }
}