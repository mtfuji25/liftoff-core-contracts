pragma solidity 0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "../uniswap-lib/FixedPoint.sol";
import './UniswapV2Library.sol';
import './libraries/UniswapV2OracleLibrary.sol';

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract ERC20PriceOracle is Initializable, UniswapV2Library {
    using FixedPoint for *;
    struct PriceOracle {
        address token0;
        address token1;
        uint    price0CumulativeLast;
        uint    price1CumulativeLast;
        uint32  blockTimestampLast;
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
    }

    uint public constant PERIOD = 15 minutes;
    mapping(address => PriceOracle) pairPriceOracle;

    function initialize(
        address tokenA,
        address tokenB
    ) public initializer {
        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(tokenA, tokenB));
        PriceOracle storage priceOracle = pairPriceOracle[address(pair)];
        priceOracle.token0 = pair.token0();
        priceOracle.token1 = pair.token1();
        priceOracle.price0CumulativeLast = pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        priceOracle.price1CumulativeLast = pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, priceOracle.blockTimestampLast) = pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, 'ERC20PriceOracle: NO_RESERVES'); // ensure that there's liquidity in the pair
    }

    function update(address pair) public {
        PriceOracle storage priceOracle = pairPriceOracle[pair];
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(pair);
        uint32 timeElapsed = blockTimestamp - priceOracle.blockTimestampLast; // overflow is desired

        // ensure that at least one full period has passed since the last update
        require(timeElapsed >= PERIOD, 'ERC20PriceOracle: PERIOD_NOT_ELAPSED');

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        priceOracle.price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - priceOracle.price0CumulativeLast) / timeElapsed));
        priceOracle.price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - priceOracle.price1CumulativeLast) / timeElapsed));

        priceOracle.price0CumulativeLast = price0Cumulative;
        priceOracle.price1CumulativeLast = price1Cumulative;
        priceOracle.blockTimestampLast = blockTimestamp;
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address pair, address token, uint amountIn) external view returns (uint amountOut) {
        PriceOracle storage priceOracle = pairPriceOracle[pair];
        if (token == priceOracle.token0) {
            amountOut = priceOracle.price0Average.mul(amountIn).decode144();
        } else {
            require(token == priceOracle.token1, 'ERC20PriceOracle: INVALID_TOKEN');
            amountOut = priceOracle.price1Average.mul(amountIn).decode144();
        }
    }
}