pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./uniswapV2Periphery/interfaces/IUniswapV2Pair.sol";


contract TokenPriceCheckpoint is ERC20, Ownable {
  
  struct Checkpoint {
      uint128 fromBlock;
      uint128 value;
  }

  mapping(address => Checkpoint[]) public priceAccumulatorHistory;
  mapping(address => bool) public isToken0;
  mapping(address => bool) public isPair;
  mapping(address => uint) public priceAccumulator;

  IUniswapV2Pair[] public pools;

  function initialize(
      uint totalSupply,
      address account
  ) public initializer {
      _mint(account, totalSupply);
  }

  function setUniswapPool(IUniswapV2Pair pair) external onlyOwner {
    require(pools.length < 10, "Cannot have more than 10 pools");

    if(address(this) == pair.token0()) {
      isToken0[address(pair)] = true;
    } else{
      require(address(this) == pair.token1(), "Token is not in pair");
    }
    isPair[address(pair)] = true;
  }
  
  function _transfer(address sender, address recipient, uint256 amount) internal {
    ERC20._transfer(sender, recipient, amount);
    if(isPair[sender]) {
      _updatePair(sender);
    }
    if(isPair[recipient]) {
      _updatePair(recipient);
    }
  }

  function _updatePair(address pair) internal {
    uint newPriceAccumulator;
    if(isToken0[pair]){
      newPriceAccumulator = IUniswapV2Pair(pair).price0CumulativeLast();
    } else {
      newPriceAccumulator = IUniswapV2Pair(pair).price1CumulativeLast();
    }      
    _updateCheckpointValueAtNow(
      priceAccumulatorHistory[pair],
      priceAccumulator[pair],
      newPriceAccumulator
    );
    priceAccumulator[pair] = newPriceAccumulator;
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
