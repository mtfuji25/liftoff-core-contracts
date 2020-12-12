pragma solidity 0.5.16;

import "./GovernorRole.sol";
import "./interfaces/ILiftoffSwap.sol";
import "./library/BasisPoints.sol";
import "./MultiPairPriceOracle.sol";
import "./uniswapV2Periphery/UniswapV2Library.sol";
import "./uniswapV2Periphery/interfaces/IERC20.sol";
import "./uniswapV2Periphery/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract LiftoffSwap is ILiftoffSwap, Initializable, ReentrancyGuard, Pausable, GovernorRole, UniswapV2Library {
  using BasisPoints for uint;
  using SafeMath for uint;
  using Math for uint;
  using Address for address;

  mapping(address => uint) public tokenEther;
  mapping(address => bool) public tokenIsSparkReady;
  mapping(address => bool) public tokenSparked;

  address public liftoffEngine;
  IERC20 lid;

  uint public lidBP;

  IUniswapV2Router01 public constant uniswapRouter = IUniswapV2Router01(0x84e924C5E04438D2c1Df1A981f7E7104952e6de1);
  address public multiPairPriceOracle;

  //TODO: Method callable by approved swappers to swap tokenEther for tokenLiq
  //TODO: Sparker for first 24 hours

  modifier onlyLiftoffEngine() {
    require(msg.sender == liftoffEngine,"Sender must be LiftoffEngine");
    _;
  }

  function init(
    address _liftoffGovernance,
    IERC20 _lid,
    uint _lidBP
  ) external initializer {
    GovernorRole.initialize(_liftoffGovernance);
    Pausable.initialize(_liftoffGovernance);
    ReentrancyGuard.initialize();
    
    lid = _lid;
    lidBP = _lidBP;
  }

  function setLiftoffEngine(address _liftoffEngine) payable external onlyGovernor {
    liftoffEngine = _liftoffEngine;
  }

  function setMultiPairPriceOracle(address _multiPairPriceOracle) payable external onlyGovernor {
    multiPairPriceOracle = _multiPairPriceOracle;
  }

  function acceptIgnite(address _token) payable external onlyLiftoffEngine {
    tokenEther[_token] = tokenEther[_token].add(msg.value);
  }

  function acceptSparkRequest(address _token) payable external onlyLiftoffEngine {
    tokenIsSparkReady[_token] = true;
  }

  function spark(address _token) external {

  }

  function ignite(address _token, uint _minWethPoolLP, uint _minLidPoolLP) external {
    require(tokenSparked[_token], "Token not yet sparked");
    //TODO: Add LP with eth
  }

  //get the amount of a token from the Oracle:
  function _getAmount(address _token, uint _amount, address _pair) public view returns (uint) {
    MultiPairPriceOracle instance = MultiPairPriceOracle(multiPairPriceOracle);
    return instance.consult(_pair, _token, _amount);
  }

  function _swapAmount(address _token, uint _amountEth, uint _slippageBP) internal {
    address _pair = UniswapV2Library.pairFor(uniswapRouter.WETH(),_token);
    uint amountToken = _getAmount(_token, _amountEth, _pair).subBP(_slippageBP);
    address[] memory path;
    path[0] = uniswapRouter.WETH();
    path[1] = _token;
    uniswapRouter.swapExactETHForTokens.value(_amountEth)(amountToken, path, address(this), now);
  }

}