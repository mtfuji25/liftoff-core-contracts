pragma solidity 0.5.16;

import "./GovernorRole.sol";
import "./interfaces/ILiftoffSwap.sol";
import "./library/BasisPoints.sol";
import "./uniswapV2Periphery/interfaces/IERC20.sol";
import "./uniswapV2Periphery/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract LiftoffSwap is ILiftoffSwap, Initializable, ReentrancyGuard, Pausable, GovernorRole {
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

  function acceptIgnite(address _token) payable external onlyLiftoffEngine {
    tokenEther[_token] = tokenEther[_token].add(msg.value);
  }

  function acceptSparkRequest(address _token) payable external onlyLiftoffEngine {
    tokenIsSparkReady[_token] = true;
  }

  function spark(address _token) external {
    require(tokenIsSparkReady[address(_token)], "Token not spark ready");
    require(!tokenSparked[address(_token)], "Token already sparked");
    tokenSparked[address(_token)] = true;
    
    uint lidEth = tokenEther[address(_token)].mulBP(lidBP);
    uint tokenEth = tokenEther[address(_token)].sub(lidEth);
    tokenEther[address(_token)] = 0;

    uint totalTokens = IERC20(_token).balanceOf(address(this));
    uint lidPoolTokens = totalTokens.mulBP(lidBP);
    uint ethPoolTokens = totalTokens.sub(lidPoolTokens);
/*
    uniswapRouter.addLiquidityETH.value(tokenEth)(
            address(_token),
            ethPoolTokens,
            ethPoolTokens,
            tokenEth,
            address(0x000000000000000000000000000000000000dEaD),
            now
        );

    swapExactETHForTokens.value(lidEth)(
      _minLid,
      [
        uniswapRouter.WETH(),
        address(lid)
      ], 
      address(this),
      now
    );*/

    uint lidAmount = lid.balanceOf(address(this));

    /*uniswapRouter.addLiquidity(
        address(lid),
        address(_token),
        uint amountADesired,
        lidAmount,
        uint amountAMin,
        lidAmount,
        address(0x000000000000000000000000000000000000dEaD),
        now
    );*/
  }

  function ignite(address _token, uint _minWethPoolLP, uint _minLidPoolLP) external {
    require(tokenSparked[_token], "Token not yet sparked");
    //TODO: Add LP with eth
  }

}