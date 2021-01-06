pragma solidity =0.6.6;

import "./interfaces/ILiftoffEngine.sol";
import "./interfaces/ILiftoffSettings.sol";
import "./interfaces/ILiftoffInsurance.sol";
import "@lidprotocol/xlock-contracts/contracts/interfaces/IXEth.sol";
import "@lidprotocol/xlock-contracts/contracts/interfaces/IXLocker.sol";
import "./library/BasisPoints.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract LiftoffEngine is
    ILiftoffEngine,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using BasisPoints for uint256;
    using SafeMathUpgradeable for uint256;
    using MathUpgradeable for uint256;

    struct TokenSale {
        uint256 startTime;
        uint256 endTime;
        uint256 softCap;
        uint256 hardCap;
        uint256 totalIgnited;
        uint256 totalSupply;
        uint256 rewardSupply;
        address projectDev;
        address deployed;
        address pair;
        bool isSparked;
        string name;
        string symbol;
        mapping(address => Ignitor) ignitors;
    }

    struct Ignitor {
        uint256 ignited;
        bool hasClaimed;
        bool hasRefunded;
    }

    ILiftoffSettings public liftoffSettings;

    mapping(uint256 => TokenSale) public tokens;
    uint256 public totalTokenSales;

    event LaunchToken(
        uint256 tokenId,
        uint256 startTime,
        uint256 endTime,
        uint256 softCap,
        uint256 hardCap,
        uint256 totalSupply,
        string name,
        string symbol,
        address dev
    );
    event Spark(uint256 tokenId, address deployed, uint256 rewardSupply);
    event Ignite(uint256 tokenId, address igniter, uint256 toIgnite);
    event ClaimReward(uint256 tokenId, address igniter, uint256 reward);
    event ClaimRefund(uint256 tokenId, address igniter);

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

    function launchToken(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _totalSupply,
        string calldata _name,
        string calldata _symbol,
        address _projectDev
    ) external override whenNotPaused returns (uint256 tokenId) {
        require(
            msg.sender == liftoffSettings.getLiftoffRegistration(),
            "Sender must be LiftoffRegistration"
        );
        require(_endTime > _startTime, "Must end after start");
        require(_startTime > now, "Must start in the future");
        require(_hardCap >= _softCap, "Hardcap must be at least softCap");
        require(_softCap >= 10 ether, "Softcap must be at least 10 ether");
        require(_totalSupply >= 1000 * (10**18), "TotalSupply must be at least 1000 tokens");
        require(_totalSupply < (10**12) * (10**18), "TotalSupply must be less than 1 trillion tokens");

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
            pair: address(0),
            name: _name,
            symbol: _symbol,
            isSparked: false
        });

        totalTokenSales++;

        emit LaunchToken(
            tokenId,
            _startTime,
            _endTime,
            _softCap,
            _hardCap,
            _totalSupply,
            _name,
            _symbol,
            _projectDev
        );
    }

    function igniteEth(uint256 _tokenSaleId)
        external
        payable
        override
        whenNotPaused
    {
        TokenSale storage tokenSale = tokens[_tokenSaleId];
        require(
            isIgniting(
                tokenSale.startTime,
                tokenSale.endTime,
                tokenSale.totalIgnited,
                tokenSale.hardCap
            ),
            "Not igniting."
        );
        uint256 toIgnite =
            getAmountToIgnite(
                msg.value,
                tokenSale.hardCap,
                tokenSale.totalIgnited
            );

        IXEth(liftoffSettings.getXEth()).deposit{value: toIgnite}();
        _addIgnite(tokenSale, msg.sender, toIgnite);

        msg.sender.transfer(msg.value.sub(toIgnite));

        emit Ignite(_tokenSaleId, msg.sender, toIgnite);
    }

    function ignite(
        uint256 _tokenSaleId,
        address _for,
        uint256 _amountXEth
    ) external override whenNotPaused {
        TokenSale storage tokenSale = tokens[_tokenSaleId];
        require(
            isIgniting(
                tokenSale.startTime,
                tokenSale.endTime,
                tokenSale.totalIgnited,
                tokenSale.hardCap
            ),
            "Not igniting."
        );
        uint256 toIgnite =
            getAmountToIgnite(
                _amountXEth,
                tokenSale.hardCap,
                tokenSale.totalIgnited
            );

        require(
            IXEth(liftoffSettings.getXEth()).transferFrom(
                msg.sender,
                address(this),
                toIgnite
            ),
            "Transfer Failed"
        );
        _addIgnite(tokenSale, _for, toIgnite);

        emit Ignite(_tokenSaleId, _for, toIgnite);
    }

    function claimReward(uint256 _tokenSaleId, address _for)
        external
        override
        whenNotPaused
    {
        TokenSale storage tokenSale = tokens[_tokenSaleId];
        Ignitor storage ignitor = tokenSale.ignitors[_for];

        require(tokenSale.isSparked, "Token must have been sparked.");
        require(!ignitor.hasClaimed, "Ignitor has already claimed");

        uint256 reward =
            getReward(
                ignitor.ignited,
                tokenSale.rewardSupply,
                tokenSale.totalIgnited
            );
        require(reward > 0, "Must have some rewards to claim.");

        ignitor.hasClaimed = true;
        require(
            IERC20(tokenSale.deployed).transfer(_for, reward),
            "Transfer failed"
        );

        emit ClaimReward(_tokenSaleId, _for, reward);
    }

    function spark(uint256 _tokenSaleId) external override whenNotPaused {
        TokenSale storage tokenSale = tokens[_tokenSaleId];

        require(
            isSparkReady(
                tokenSale.endTime,
                tokenSale.totalIgnited,
                tokenSale.hardCap,
                tokenSale.softCap,
                tokenSale.isSparked
            ),
            "Not spark ready"
        );

        tokenSale.isSparked = true;

        uint256 xEthBuy = _deployViaXLock(tokenSale);
        _allocateTokensPostDeploy(tokenSale);
        _insuranceRegistration(tokenSale, _tokenSaleId, xEthBuy);

        emit Spark(_tokenSaleId, tokenSale.deployed, tokenSale.rewardSupply);
    }

    function claimRefund(uint256 _tokenSaleId, address _for)
        external
        override
        whenNotPaused
    {
        TokenSale storage tokenSale = tokens[_tokenSaleId];
        Ignitor storage ignitor = tokenSale.ignitors[_for];

        require(
            isRefunding(
                tokenSale.endTime,
                tokenSale.softCap,
                tokenSale.totalIgnited
            ),
            "Not refunding"
        );

        require(!ignitor.hasRefunded, "Ignitor has already refunded");
        ignitor.hasRefunded = true;

        require(
            IXEth(liftoffSettings.getXEth()).transfer(_for, ignitor.ignited),
            "Transfer failed"
        );

        emit ClaimRefund(_tokenSaleId, _for);
    }

    function getTokenSale(uint256 _tokenSaleId)
        external
        view
        override
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 softCap,
            uint256 hardCap,
            uint256 totalIgnited,
            uint256 totalSupply,
            uint256 rewardSupply,
            address projectDev,
            address deployed,
            bool isSparked
        )
    {
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

    function getTokenSaleForInsurance(uint256 _tokenSaleId)
        external
        view
        override
        returns (
            uint256 totalIgnited,
            uint256 rewardSupply,
            address projectDev,
            address pair,
            address deployed
        )
    {
        TokenSale storage tokenSale = tokens[_tokenSaleId];
        totalIgnited = tokenSale.totalIgnited;
        rewardSupply = tokenSale.rewardSupply;
        projectDev = tokenSale.projectDev;
        pair = tokenSale.pair;
        deployed = tokenSale.deployed;
    }

    function isSparkReady(
        uint256 endTime,
        uint256 totalIgnited,
        uint256 hardCap,
        uint256 softCap,
        bool isSparked
    ) public view override returns (bool) {
        if (
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
        uint256 startTime,
        uint256 endTime,
        uint256 totalIgnited,
        uint256 hardCap
    ) public view override returns (bool) {
        if (now < startTime || now > endTime || totalIgnited >= hardCap) {
            return false;
        } else {
            return true;
        }
    }

    function isRefunding(
        uint256 endTime,
        uint256 softCap,
        uint256 totalIgnited
    ) public view override returns (bool) {
        if (totalIgnited >= softCap || now <= endTime) {
            return false;
        } else {
            return true;
        }
    }

    function getReward(
        uint256 ignited,
        uint256 rewardSupply,
        uint256 totalIgnited
    ) public pure override returns (uint256 reward) {
        return ignited.mul(rewardSupply).div(totalIgnited);
    }

    function getAmountToIgnite(
        uint256 amountXEth,
        uint256 hardCap,
        uint256 totalIgnited
    ) public pure returns (uint256 toIgnite) {
        uint256 maxIgnite = hardCap.sub(totalIgnited);

        if (maxIgnite < amountXEth) {
            toIgnite = maxIgnite;
        } else {
            toIgnite = amountXEth;
        }
    }

    function _deployViaXLock(TokenSale storage tokenSale)
        internal
        returns (uint256 xEthBuy)
    {
        uint256 xEthLocked =
            tokenSale.totalIgnited.mulBP(liftoffSettings.getEthXLockBP());
        xEthBuy = tokenSale.totalIgnited.mulBP(liftoffSettings.getEthBuyBP());

        (address deployed, address pair) =
            IXLocker(liftoffSettings.getXLocker()).launchERC20(
                tokenSale.name,
                tokenSale.symbol,
                tokenSale.totalSupply,
                xEthLocked
            );

        _swapExactXEthForTokens(
            xEthBuy,
            IERC20(liftoffSettings.getXEth()),
            IUniswapV2Pair(pair)
        );

        tokenSale.pair = pair;
        tokenSale.deployed = deployed;

        return xEthBuy;
    }

    function _allocateTokensPostDeploy(TokenSale storage tokenSale) internal {
        IERC20 deployed = IERC20(tokenSale.deployed);
        uint256 balance = deployed.balanceOf(address(this));
        tokenSale.rewardSupply = balance.mulBP(
            liftoffSettings.getTokenUserBP()
        );
    }

    function _insuranceRegistration(
        TokenSale storage tokenSale,
        uint256 _tokenSaleId,
        uint256 _xEthBuy
    ) internal {
        IERC20 deployed = IERC20(tokenSale.deployed);
        uint256 toInsurance =
            deployed.balanceOf(address(this)).sub(tokenSale.rewardSupply);
        address liftoffInsurance = liftoffSettings.getLiftoffInsurance();
        deployed.transfer(liftoffInsurance, toInsurance);
        IXEth(liftoffSettings.getXEth()).transfer(
            liftoffInsurance,
            tokenSale.totalIgnited.sub(_xEthBuy)
        );

        ILiftoffInsurance(liftoffInsurance).register(_tokenSaleId);
    }

    function _addIgnite(
        TokenSale storage tokenSale,
        address _for,
        uint256 toIgnite
    ) internal {
        Ignitor storage ignitor = tokenSale.ignitors[_for];
        ignitor.ignited = ignitor.ignited.add(toIgnite);
        tokenSale.totalIgnited = tokenSale.totalIgnited.add(toIgnite);
    }

    //WARNING: Not tested with transfer tax tokens. Will probably fail with such.
    function _swapExactXEthForTokens(
        uint256 amountIn,
        IERC20 xEth,
        IUniswapV2Pair pair
    ) internal {
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        bool token0IsXEth = pair.token0() == address(xEth);
        (uint256 reserveIn, uint256 reserveOut) =
            token0IsXEth ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 amountOut =
            UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
        require(xEth.transfer(address(pair), amountIn), "Transfer failed");
        (uint256 amount0Out, uint256 amount1Out) =
            token0IsXEth ? (uint256(0), amountOut) : (amountOut, uint256(0));
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
    }
}
