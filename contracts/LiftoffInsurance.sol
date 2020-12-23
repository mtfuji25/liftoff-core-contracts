pragma solidity =0.6.6;

import "./interfaces/ILiftoffSettings.sol";
import "./interfaces/ILiftoffEngine.sol";
import "./LiftoffEngine.sol";
import "./interfaces/ILiftoffInsurance.sol";
import "./xlock/IXeth.sol";
import "./library/BasisPoints.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract LiftoffInsurance is
    ILiftoffInsurance,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using BasisPoints for uint256;
    using SafeMathUpgradeable for uint256;
    using MathUpgradeable for uint256;

    struct TokenInsurance {
        uint256 startTime;
        uint256 totalIgnited;
        uint256 tokensPerEthWad;
        uint256 baseXEth;
        uint256 baseTokenLidPool;
        uint256 redeemedXEth;
        uint256 claimedXEth;
        uint256 claimedTokenLidPool;
        address deployed;
        address projectDev;
        bool isUnwound;
        bool hasBaseFeeClaimed;
    }

    ILiftoffSettings public liftoffSettings;

    mapping(uint256 => TokenInsurance) public tokenInsurances;
    mapping(uint256 => bool) public tokenIsRegistered;
    mapping(uint256 => bool) public insuranceIsInitialized;

    event Register(uint256 tokenId);
    event CreateInsurance(
        uint256 tokenId,
        uint256 startTime,
        uint256 tokensPerEthWad,
        uint256 baseXEth,
        uint256 baseTokenLidPool,
        uint256 totalIgnited,
        address deployed,
        address dev
    );
    event ClaimBaseFee(uint256 tokenId);
    event Claim(uint256 tokenId, uint256 ethClaimed, uint256 tokenClaimed);
    event Redeem(uint256 tokenId, uint256 redeemEth);

    function initialize(ILiftoffSettings _liftoffSettings)
        external
        initializer
    {
        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        liftoffSettings = _liftoffSettings;
    }

    function setLiftoffSettings(ILiftoffSettings _liftoffSettings)
        public
        onlyOwner
    {
        liftoffSettings = _liftoffSettings;
    }

    function register(uint256 _tokenSaleId) external override {
        address liftoffEngine = liftoffSettings.getLiftoffEngine();
        require(msg.sender == liftoffEngine, "Sender must be Liftoff Engine");
        tokenIsRegistered[_tokenSaleId] = true;

        emit Register(_tokenSaleId);
    }

    function redeem(uint256 _tokenSaleId, uint256 _amount) external override {
        TokenInsurance storage tokenInsurance = tokenInsurances[_tokenSaleId];
        require(
            insuranceIsInitialized[_tokenSaleId],
            "Insurance not initialized"
        );

        IERC20 token = IERC20(tokenInsurance.deployed);
        IXeth xeth = IXeth(liftoffSettings.getXEth());
        uint256 initialBalance = token.balanceOf(address(this));
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        //In case token has a transfer tax or burn.
        uint256 amountReceived =
            token.balanceOf(address(this)).sub(initialBalance);

        uint256 xEthValue =
            amountReceived.mul(1 ether).div(tokenInsurance.tokensPerEthWad);
        require(
            xEthValue >= 0.001 ether,
            "Amount must have value of at least 0.001 xETH"
        );

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(xeth);

        require(
            //After the first period (1 week)
            now >
                tokenInsurance.startTime.add(
                    liftoffSettings.getInsurancePeriod()
                ) &&
                //Already reached the baseXEth
                tokenInsurance.baseXEth <
                tokenInsurance.redeemedXEth.add(xEthValue),
            "Insurance exhausted"
        );

        if (
            //Still in the first period (1 week)
            now <=
            tokenInsurance.startTime.add(
                liftoffSettings.getInsurancePeriod()
            ) &&
            //Already reached the baseXEth
            tokenInsurance.baseXEth < tokenInsurance.redeemedXEth.add(xEthValue)
        ) {
            //Trigger unwind
            tokenInsurance.isUnwound = true;
        }

        if (tokenInsurance.isUnwound) {
            //All tokens are sold on market during unwind, to maximize insurance returns.
            IUniswapV2Router02(liftoffSettings.getUniswapRouter())
                .swapExactTokensForTokens(
                token.balanceOf(address(this)),
                0, //Since all tokens will ultimately be sold, arb does not matter
                path,
                address(this),
                now
            );
        }
        tokenInsurance.redeemedXEth = tokenInsurance.redeemedXEth.add(
            xEthValue
        );
        xeth.transfer(msg.sender, xEthValue);

        emit Redeem(_tokenSaleId, xEthValue);
    }

    function claim(uint256 _tokenSaleId) external override {
        TokenInsurance storage tokenInsurance = tokenInsurances[_tokenSaleId];
        require(
            insuranceIsInitialized[_tokenSaleId],
            "Insurance not initialized"
        );
        require(!tokenInsurance.isUnwound, "Token insurance is unwound.");

        uint256 cycles =
            now.sub(tokenInsurance.startTime).mod(
                liftoffSettings.getInsurancePeriod()
            );

        IXeth xeth = IXeth(liftoffSettings.getXEth());

        //For first 7 days, only claim base fee
        uint256 totalIgnited = tokenInsurance.totalIgnited;

        if (!tokenInsurance.hasBaseFeeClaimed) {
            uint256 baseFee =
                totalIgnited.mulBP(liftoffSettings.getBaseFeeBP());
            require(
                xeth.transfer(liftoffSettings.getLidTreasury(), baseFee),
                "Transfer failed"
            );
            tokenInsurance.hasBaseFeeClaimed = true;

            emit ClaimBaseFee(_tokenSaleId);

            return;
        }
        require(cycles > 0, "Cannot claim until after first cycle ends.");

        //NOTE: The totals are not actually held by insurance.
        //The ethBuyBP was used by liftoffEngine, and baseFeeBP is seperate above.
        //So the total BP transferred here will always be 10000-ethBuyBP-baseFeeBP

        //Part 1: xEth
        uint256 totalFinalClaim = totalIgnited.sub(tokenInsurance.redeemedXEth);
        uint256 totalMaxClaim = totalFinalClaim.mul(cycles).div(10); //10 periods hardcoded
        if (totalMaxClaim > totalFinalClaim) totalMaxClaim = totalFinalClaim;
        uint256 totalClaimable = totalMaxClaim.sub(tokenInsurance.claimedXEth);

        tokenInsurance.claimedXEth = tokenInsurance.claimedXEth.add(
            totalClaimable
        );

        require(
            xeth.transfer(
                tokenInsurance.projectDev,
                totalClaimable.mulBP(liftoffSettings.getProjectDevBP())
            ),
            "Transfer xEth projectDev failed"
        );
        require(
            xeth.transfer(
                liftoffSettings.getLidTreasury(),
                totalClaimable.mulBP(liftoffSettings.getMainFeeBP())
            ),
            "Transfer xEth lidTreasury failed"
        );
        require(
            xeth.transfer(
                liftoffSettings.getLidPoolManager(),
                totalClaimable.mulBP(liftoffSettings.getLidPoolBP())
            ),
            "Transfer xEth lidPoolManager failed"
        );

        //Part 2: token
        uint256 totalFinalTokenClaim = tokenInsurance.baseTokenLidPool;
        uint256 totalMaxTokenClaim = totalFinalTokenClaim.mul(cycles).div(10);
        if (totalMaxTokenClaim > totalFinalTokenClaim)
            totalMaxTokenClaim = totalFinalTokenClaim;
        uint256 totalTokenClaimable =
            totalMaxTokenClaim.sub(tokenInsurance.claimedTokenLidPool);

        tokenInsurance.claimedTokenLidPool = tokenInsurance
            .claimedTokenLidPool
            .add(totalTokenClaimable);

        require(
            IERC20(tokenInsurance.deployed).transfer(
                liftoffSettings.getLidPoolManager(),
                totalTokenClaimable
            ),
            "Transfer token to lidPoolManager failed"
        );

        emit Claim(_tokenSaleId, totalClaimable, totalTokenClaimable);
    }

    function createInsurance(uint256 _tokenSaleId) external override {
        require(
            !insuranceIsInitialized[_tokenSaleId],
            "Insurance already initialized"
        );
        require(tokenIsRegistered[_tokenSaleId], "Token not yet registered.");
        insuranceIsInitialized[_tokenSaleId] = true;
        (
            uint256 totalIgnited,
            uint256 rewardSupply,
            address projectDev,
            address deployed
        ) =
            ILiftoffEngine(liftoffSettings.getLiftoffEngine())
                .getTokenSaleForInsurance(_tokenSaleId);

        require(
            rewardSupply.mul(1 ether).div(1000) > totalIgnited,
            "Must have at least 3 digits"
        );

        tokenInsurances[_tokenSaleId] = TokenInsurance({
            startTime: now,
            totalIgnited: totalIgnited,
            tokensPerEthWad: rewardSupply
                .mul(1 ether)
                .subBP(liftoffSettings.getBaseFeeBP())
                .div(totalIgnited),
            baseXEth: totalIgnited.sub(
                totalIgnited.mulBP(liftoffSettings.getEthBuyBP())
            ),
            baseTokenLidPool: IERC20(deployed).balanceOf(address(this)),
            redeemedXEth: 0,
            claimedXEth: 0,
            claimedTokenLidPool: 0,
            deployed: deployed,
            projectDev: projectDev,
            isUnwound: false,
            hasBaseFeeClaimed: false
        });

        emit CreateInsurance(
            _tokenSaleId,
            tokenInsurances[_tokenSaleId].startTime,
            tokenInsurances[_tokenSaleId].tokensPerEthWad,
            tokenInsurances[_tokenSaleId].baseXEth,
            tokenInsurances[_tokenSaleId].baseTokenLidPool,
            totalIgnited,
            deployed,
            projectDev
        );
    }
}
