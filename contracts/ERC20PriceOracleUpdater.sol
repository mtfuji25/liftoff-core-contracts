pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./uniswapV2Periphery/interfaces/IUniswapV2Pair.sol";
import "./uniswap-lib/FixedPoint.sol";
import "./GovernorRole.sol";


contract ERC20PriceOracleUpdater is ERC20, GovernorRole {
  using FixedPoint for *;
  struct Checkpoint {
      uint128 timestamp;
      uint128 value;
  }
  mapping(address => bool) public isToken0;
  mapping(address => bool) public isPair;

  IUniswapV2Pair[] public pools;

  function initialize(
      uint totalSupply,
      address account,
      address governor
  ) public initializer {
    _mint(account, totalSupply);
    GovernorRole.initialize(governor);
  }

  function setUniswapPool(IUniswapV2Pair pair) external onlyGovernor {
    require(pools.length < 10, "Cannot have more than 10 pools");

    if(address(this) == pair.token0()) {
      isToken0[address(pair)] = true;
    } else{
      require(address(this) == pair.token1(), "Token is not in pair");
    }
    isPair[address(pair)] = true;
  }


  function _transfer(address sender, address recipient, uint256 amount) internal {
    super._transfer(sender, recipient, amount);
    if(isPair[sender]) {
      _updatePair(sender);
    }
    if(isPair[recipient]) {
      _updatePair(recipient);
    }
  }

  function _updatePair(address pair) internal {
    //TODO: Call update on appropriate price oracle
  }
  
}
