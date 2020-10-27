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

  //TODO: Method callable by approved swappers to swap tokenEther for tokenLiq
  //TODO: Sparker for first 24 hours

  function init(
    address _liftoffGovernance
  ) external initializer {
    Ownable.initialize(_liftoffGovernance);
    Pausable.initialize(_liftoffGovernance);
    ReentrancyGuard.initialize();
  }

  function acceptIgnite(address _token) payable external {
    tokenEther[_token] = tokenEther[_token].add(msg.value);
  }



}