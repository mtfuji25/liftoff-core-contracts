pragma solidity 0.5.16;

import "./interfaces/ILiftoffSwap.sol";
import "./library/BasisPoints.sol";
import "./uniswapV2Periphery/interfaces/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract LiftoffSwap is ILiftoffSwap, Initializable, Ownable, ReentrancyGuard, Pausable {
  using BasisPoints for uint;
  using SafeMath for uint;
  using Math for uint;
  using Address for address;

  mapping(address => uint) tokenEther;

  address public liftoffEngine;

  //TODO: Method callable by approved swappers to swap tokenEther for tokenLiq
  //TODO: Sparker for first 24 hours

  modifier onlyLiftoffEngine() {
    require(msg.sender == liftoffEngine,"Sender must be LiftoffEngine");
    _;
  }

  function init(
    address _liftoffGovernance
  ) external initializer {
    Ownable.initialize(_liftoffGovernance);
    Pausable.initialize(_liftoffGovernance);
    ReentrancyGuard.initialize();
  }

  function setLiftoffEngine(address _liftoffEngine) payable external onlyOwner {
    liftoffEngine = _liftoffEngine;
  }

  function acceptIgnite(address _token) payable external onlyLiftoffEngine {
    tokenEther[_token] = tokenEther[_token].add(msg.value);
  }

  function acceptSpark(address _token) payable external onlyLiftoffEngine {
    //TODO: create liquidity pools
  }



}