pragma solidity =0.6.6;

import "./interfaces/ILiftoffSettings.sol";
import "./interfaces/ILiftoffEngine.sol";
import "./LiftoffEngine.sol";
import "./interfaces/ILiftoffInsurance.sol";
import "./interfaces/ILiftoffPartnerships.sol";
import "./library/BasisPoints.sol";
import "@lidprotocol/xlock-contracts/contracts/interfaces/IXLocker.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract LiftoffInsurance is
    ILiftoffInsurance,
    Initializable,
    OwnableUpgradeable,
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
        address pair;
        address deployed;
        address projectDev;
        bool isUnwound;
        bool hasBaseFeeClaimed;
    }

    ILiftoffSettings public liftoffSettings;

    mapping(uint256 => TokenInsurance) public tokenInsurances;
    mapping(uint256 => bool) public tokenIsRegistered;
    mapping(uint256 => bool) public insuranceIsInitialized;
    mapping(uint256 => uint256) public tokenIdBonusInsurance;

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
    event ClaimBaseFee(uint256 tokenId, uint256 baseFee);
    event Claim(uint256 tokenId, uint256 xEthClaimed, uint256 tokenClaimed);
    event Redeem(uint256 tokenId, uint256 redeemEth);

    function initialize(ILiftoffSettings _liftoffSettings)
        external
        initializer
    {
        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
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
        require(!tokenIsRegistered[_tokenSaleId], "Token already registered");
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
        IERC20 xeth = IXEth(liftoffSettings.getXEth());

        uint256 xEthValue =
            _pullTokensForRedeem(tokenInsurance, token, _amount);

        require(
            !isInsuranceExhausted(
                now,
                tokenInsurance.startTime,
                liftoffSettings.getInsurancePeriod(),
                xEthValue,
                tokenInsurance.baseXEth,
                tokenInsurance.redeemedXEth.add(xEthValue),
                tokenInsurance.claimedXEth,
                tokenInsurance.isUnwound
            ),
            "Redeem request exceeds available insurance."
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
            IXLocker(liftoffSettings.getXLocker()).setBlacklistUniswapBuys(
                tokenInsurance.pair,
                address(token),
                true
            );
        }

        if (tokenInsurance.isUnwound) {
            //All tokens are sold on market during unwind, to maximize insurance returns.
            _swapExactTokensForXEth(
                token.balanceOf(address(this)),
                token,
                IUniswapV2Pair(tokenInsurance.pair)
            );
        }
        tokenInsurance.redeemedXEth = tokenInsurance.redeemedXEth.add(
            xEthValue
        );
        require(xeth.transfer(msg.sender, xEthValue), "Transfer failed.");

        emit Redeem(_tokenSaleId, xEthValue);
    }

    function claim(uint256 _tokenSaleId) external override {
        TokenInsurance storage tokenInsurance = tokenInsurances[_tokenSaleId];
        require(
            insuranceIsInitialized[_tokenSaleId],
            "Insurance not initialized"
        );
        require(
            tokenIdBonusInsurance[_tokenSaleId] > 0,
            "Nothing to claim"
        );

        tokenIdBonusInsurance[_tokenSaleId] = 0;

        uint256 cycles =
            now.sub(tokenInsurance.startTime).div(
                liftoffSettings.getInsurancePeriod()
            );

        IXEth xeth = IXEth(liftoffSettings.getXEth());

        bool didBaseFeeClaim =
            _baseFeeClaim(tokenInsurance, xeth, _tokenSaleId);
        if (didBaseFeeClaim) {
            return; //If claiming base fee, ONLY claim base fee.
        }
        require(!tokenInsurance.isUnwound, "Token insurance is unwound.");

        //For first 7 days, only claim base fee
        require(cycles > 0, "Cannot claim until after first cycle ends.");

        uint256 totalXethClaimed =
            _xEthClaimDistribution(tokenInsurance, _tokenSaleId, cycles, xeth);

        uint256 totalTokenClaimed =
            _tokenClaimDistribution(tokenInsurance, cycles);

        emit Claim(_tokenSaleId, totalXethClaimed, totalTokenClaimed);
    }

    function createInsurance(uint256 _tokenSaleId) external override {
        require(
            canCreateInsurance(
                insuranceIsInitialized[_tokenSaleId],
                tokenIsRegistered[_tokenSaleId]
            ),
            "Cannot create insurance"
        );

        insuranceIsInitialized[_tokenSaleId] = true;

        (
            uint256 totalIgnited,
            uint256 rewardSupply,
            address projectDev,
            address pair,
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
                .div(totalIgnited.subBP(liftoffSettings.getBaseFeeBP()))
                .add(1), //division error safety margin,
            baseXEth: totalIgnited.sub(
                totalIgnited.mulBP(liftoffSettings.getEthBuyBP())
            ),
            baseTokenLidPool: IERC20(deployed).balanceOf(address(this)),
            redeemedXEth: 0,
            claimedXEth: 0,
            claimedTokenLidPool: 0,
            pair: pair,
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

    function getTokenInsuranceUints(uint256 _tokenSaleId)
        external
        view
        override
        returns (
            uint256 startTime,
            uint256 totalIgnited,
            uint256 tokensPerEthWad,
            uint256 baseXEth,
            uint256 baseTokenLidPool,
            uint256 redeemedXEth,
            uint256 claimedXEth,
            uint256 claimedTokenLidPool
        )
    {
        TokenInsurance storage t = tokenInsurances[_tokenSaleId];

        startTime = t.startTime;
        totalIgnited = t.totalIgnited;
        tokensPerEthWad = t.tokensPerEthWad;
        baseXEth = t.baseXEth;
        baseTokenLidPool = t.baseTokenLidPool;
        redeemedXEth = t.redeemedXEth;
        claimedXEth = t.claimedXEth;
        claimedTokenLidPool = t.claimedTokenLidPool;
    }

    function getTokenInsuranceOthers(uint256 _tokenSaleId)
        external
        view
        override
        returns (
            address pair,
            address deployed,
            address projectDev,
            bool isUnwound,
            bool hasBaseFeeClaimed
        )
    {
        TokenInsurance storage t = tokenInsurances[_tokenSaleId];

        pair = t.pair;
        deployed = t.deployed;
        projectDev = t.projectDev;
        isUnwound = t.isUnwound;
        hasBaseFeeClaimed = t.hasBaseFeeClaimed;
    }

    function isInsuranceExhausted(
        uint256 currentTime,
        uint256 startTime,
        uint256 insurancePeriod,
        uint256 xEthValue,
        uint256 baseXEth,
        uint256 redeemedXEth,
        uint256 claimedXEth,
        bool isUnwound
    ) public pure override returns (bool) {
        if (isUnwound) {
            //Never exhausted when unwound
            return false;
        }
        if (
            //After the first period (1 week)
            currentTime > startTime.add(insurancePeriod) &&
            //Already reached the baseXEth
            baseXEth < redeemedXEth.add(claimedXEth).add(xEthValue)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function canCreateInsurance(
        bool _insuranceIsInitialized,
        bool _tokenIsRegistered
    ) public pure override returns (bool) {
        if (!_insuranceIsInitialized && _tokenIsRegistered) {
            return true;
        }
        return false;
    }

    function getRedeemValue(uint256 amount, uint256 tokensPerEthWad)
        public
        pure
        override
        returns (uint256)
    {
        return amount.mul(1 ether).div(tokensPerEthWad);
    }

    function getTotalTokenClaimable(
        uint256 baseTokenLidPool,
        uint256 cycles,
        uint256 claimedTokenLidPool
    ) public pure override returns (uint256) {
        uint256 totalMaxTokenClaim = baseTokenLidPool.mul(cycles).div(10);
        if (totalMaxTokenClaim > baseTokenLidPool)
            totalMaxTokenClaim = baseTokenLidPool;
        return totalMaxTokenClaim.sub(claimedTokenLidPool);
    }

    function getTotalXethClaimable(
        uint256 totalIgnited,
        uint256 redeemedXEth,
        uint256 claimedXEth,
        uint256 cycles
    ) public pure override returns (uint256) {
        if (cycles == 0) return 0;
        uint256 totalFinalClaim =
            totalIgnited.sub(redeemedXEth).sub(claimedXEth);
        uint256 totalMaxClaim = totalFinalClaim.mul(cycles).div(10); //10 periods hardcoded
        if (totalMaxClaim > totalFinalClaim) totalMaxClaim = totalFinalClaim;
        return totalMaxClaim;
    }

    function increaseInsuranceBonus(uint256 tokenId, uint256 wad) external override {
        IERC20 xeth = IXEth(liftoffSettings.getXEth());
        require(xeth.transferFrom(msg.sender, address(this), wad), "Transfer failed");
        tokenIdBonusInsurance[tokenId] += wad;
    }

    function _pullTokensForRedeem(
        TokenInsurance storage tokenInsurance,
        IERC20 token,
        uint256 _amount
    ) internal returns (uint256 xEthValue) {
        uint256 initialBalance = token.balanceOf(address(this));
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        //In case token has a transfer tax or burn.
        uint256 amountReceived =
            token.balanceOf(address(this)).sub(initialBalance);

        xEthValue = getRedeemValue(
            amountReceived,
            tokenInsurance.tokensPerEthWad
        );
        require(
            xEthValue >= 0.001 ether,
            "Amount must have value of at least 0.001 xETH"
        );
        return xEthValue;
    }

    function _xEthClaimDistribution(
        TokenInsurance storage tokenInsurance,
        uint256 tokenId,
        uint256 cycles,
        IERC20 xeth
    ) internal returns (uint256 totalClaimed) {
        uint256 totalClaimable =
            getTotalXethClaimable(
                tokenInsurance.totalIgnited,
                tokenInsurance.redeemedXEth,
                tokenInsurance.claimedXEth,
                cycles
            );

        tokenInsurance.claimedXEth = tokenInsurance.claimedXEth.add(
            totalClaimable
        );

        uint256 projectDevBP = liftoffSettings.getProjectDevBP();

        //For payments to partners
        address liftoffPartnerships = liftoffSettings.getLiftoffPartnerships();
        (, uint256 totalBPForParnterships) =
            ILiftoffPartnerships(liftoffPartnerships).getTokenSalePartnerships(
                tokenId
            );

        if (totalBPForParnterships > 0) {
            projectDevBP = projectDevBP.sub(totalBPForParnterships);
            uint256 wad = totalClaimable.mulBP(totalBPForParnterships);
            require(
                xeth.transfer(liftoffPartnerships, wad),
                "Transfer xEth projectDev failed"
            );
            ILiftoffPartnerships(liftoffPartnerships).addFees(tokenId, wad);
        }

        //NOTE: The totals are not actually held by insurance.
        //The ethBuyBP was used by liftoffEngine, and baseFeeBP is seperate above.
        //So the total BP transferred here will always be 10000-ethBuyBP-baseFeeBP
        require(
            xeth.transfer(
                tokenInsurance.projectDev,
                totalClaimable.mulBP(projectDevBP)
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
        return totalClaimable;
    }

    function _tokenClaimDistribution(
        TokenInsurance storage tokenInsurance,
        uint256 cycles
    ) internal returns (uint256 totalClaimed) {
        uint256 totalTokenClaimable =
            getTotalTokenClaimable(
                tokenInsurance.baseTokenLidPool,
                cycles,
                tokenInsurance.claimedTokenLidPool
            );
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
        return totalTokenClaimable;
    }

    function _baseFeeClaim(
        TokenInsurance storage tokenInsurance,
        IERC20 xeth,
        uint256 _tokenSaleId
    ) internal returns (bool didClaim) {
        if (!tokenInsurance.hasBaseFeeClaimed) {
            uint256 baseFee =
                tokenInsurance.totalIgnited.mulBP(
                    liftoffSettings.getBaseFeeBP() - 30 //30 BP is taken by uniswap during unwind
                );
            require(
                xeth.transfer(liftoffSettings.getLidTreasury(), baseFee),
                "Transfer failed"
            );
            tokenInsurance.hasBaseFeeClaimed = true;

            emit ClaimBaseFee(_tokenSaleId, baseFee);

            return true;
        } else {
            return false;
        }
    }

    function _swapExactTokensForXEth(
        uint256 amountIn,
        IERC20 token,
        IUniswapV2Pair pair
    ) internal {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        bool token0IsToken = pair.token0() == address(token);
        (uint256 reserveIn, uint256 reserveOut) =
            token0IsToken ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 amountOut =
            UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
        require(token.transfer(address(pair), amountIn), "Transfer failed");
        (uint256 amount0Out, uint256 amount1Out) =
            token0IsToken ? (uint256(0), amountOut) : (amountOut, uint256(0));
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
    }
}
