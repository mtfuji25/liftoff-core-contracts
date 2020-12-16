pragma solidity 0.5.16;

import "./interfaces/ILiftoffSettings.sol";
import "./interfaces/ILiftoffEngine.sol";
import "./LiftoffEngine.sol";
import "./interfaces/ILiftoffInsurance.sol";
import "./xlock/IXeth.sol";
import "./library/BasisPoints.sol";
import "./uniswapV2Periphery/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract LiftoffInsurance is ILiftoffInsurance, Initializable, Ownable, ReentrancyGuard, Pausable {
  using BasisPoints for uint;
  using SafeMath for uint;
  using Math for uint;

  struct TokenInsurance {
    uint startTime;
    uint tokensPerEthWad;
    uint baseXEth;
    uint baseTokenLidPool;
    uint redeemedXEth;
    uint claimedXEth;
    uint claimedTokenLidPool;
    address deployed;
    bool isUnwound;
  }

  ILiftoffSettings public liftoffSettings;

  mapping(uint => TokenInsurance) public tokenInsurances;
  mapping(uint => bool) public tokenIsRegistered;
  mapping(uint => bool) public insuranceIsInitialized;

  function initialize(
    address _liftoffGovernance,
    ILiftoffSettings _liftoffSettings
  ) external initializer {
    Ownable.initialize(_liftoffGovernance);
    Pausable.initialize(_liftoffGovernance);
    ReentrancyGuard.initialize();
    liftoffSettings = _liftoffSettings;
  }

  function setLiftoffSettings(
    ILiftoffSettings _liftoffSettings
  ) public onlyOwner {
    liftoffSettings = _liftoffSettings;
  }

  function register(uint _tokenSaleId) external {
    address liftoffEngine = liftoffSettings.getLiftoffEngine();
    require(msg.sender == liftoffEngine, "Sender must be Liftoff Engine");
    tokenIsRegistered[_tokenSaleId] = true;
  }

  function redeem(uint _tokenSaleId, uint _amount) external {
    TokenInsurance storage tokenInsurance = tokenInsurances[_tokenSaleId];
    require(insuranceIsInitialized[_tokenSaleId], "Insurance not initialized");

    IERC20 token = IERC20(tokenInsurance.deployed);
    IXeth xeth = IXeth(liftoffSettings.getXEth());
    uint initialBalance = token.balanceOf(address(this));
    require(
      token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
    //In case token has a transfer tax or burn.
    uint amountReceived = token.balanceOf(address(this)).sub(initialBalance);

    uint xEthValue = amountReceived.mul(1 ether).div(tokenInsurance.tokensPerEthWad);
    require(xEthValue >= 0.001 ether, "Amount must have value of at least 0.001 xETH");

    address[] memory path = new address[](2);
    path[0] = address(token);
    path[1] = address(xeth);

    require(
      //After the first period (1 week)
      now > tokenInsurance.startTime.add(liftoffSettings.getInsurancePeriod()) &&
      //Already reached the baseXEth
      tokenInsurance.baseXEth < tokenInsurance.redeemedXEth.add(xEthValue),
      "Insurance exhausted"
    );

    if(
      //Still in the first period (1 week)
      now <= tokenInsurance.startTime.add(liftoffSettings.getInsurancePeriod()) &&
      //Already reached the baseXEth
      tokenInsurance.baseXEth < tokenInsurance.redeemedXEth.add(xEthValue)
    ) {
      //Trigger unwind
      tokenInsurance.isUnwound = true;
    }

    if(tokenInsurance.isUnwound) {
      //All tokens are sold on market during unwind, to maximize insurance returns.
      IUniswapV2Router01(liftoffSettings.getUniswapRouter()).swapExactTokensForTokens(
        token.balanceOf(address(this)),
        0, //Since all tokens will ultimately be sold, arb does not matter
        path,
        address(this),
        now
      );
    }
    tokenInsurance.redeemedXEth = tokenInsurance.redeemedXEth.add(xEthValue);
    xeth.transfer(msg.sender, xEthValue);
  }

  function claim(uint _tokenSaleId) external {
    TokenInsurance storage tokenInsurance = tokenInsurances[_tokenSaleId];
    require(insuranceIsInitialized[_tokenSaleId], "Insurance not initialized");
    uint cycles = now.sub(tokenInsurance.startTime).mod(7 days);
    require(cycles > 0, "Must wait 7 days for first claim");

    //TODO: If is unwound, only half of the base fee is claimed. No other claims.

    //TODO:
    //1) calculate all final claim values, use totalIgnited.sub(redeemedXEth)
    //2) calculate current claim values cycles/10 except for primaryfee
    //3) Check delta, if more than 0 then send
    
  }

  function createInsurance(uint _tokenSaleId) external {
    require(!insuranceIsInitialized[_tokenSaleId], "Insurance already initialized");
    require(tokenIsRegistered[_tokenSaleId], "Token not yet registered.");

    (
      uint totalIgnited,
      uint rewardSupply,
      address deployed
    ) = ILiftoffEngine(liftoffSettings.getLiftoffEngine()).getTokenSaleForInsurance(_tokenSaleId);
    
    require(rewardSupply.mul(1 ether).div(1000) > totalIgnited, "Must have at least 3 digits");

    tokenInsurances[_tokenSaleId] = TokenInsurance({
      startTime: now,
      tokensPerEthWad: rewardSupply
        .mul(1 ether)
        .subBP(liftoffSettings.getBaseFee())
        .div(totalIgnited),
      baseXEth: totalIgnited.sub(
        totalIgnited.mulBP(
          liftoffSettings.getEthBuyBP()
        )
      ),
      baseTokenLidPool: IERC20(deployed).balanceOf(address(this)),
      redeemedXEth: 0,
      claimedXEth: 0,
      claimedTokenLidPool: 0,
      deployed: deployed,
      isUnwound: false
    });
  }
}