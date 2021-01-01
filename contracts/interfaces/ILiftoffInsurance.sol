pragma solidity =0.6.6;

interface ILiftoffInsurance {
    function register(uint256 _tokenSaleId) external;

    function redeem(uint256 _tokenSaleId, uint256 _amount) external;

    function claim(uint256 _tokenSaleId) external;

    function createInsurance(uint256 _tokenSaleId) external;

    function canCreateInsurance(
        bool insuranceIsInitialized,
        bool tokenIsRegistered
    ) external pure returns (bool);

    function getTotalTokenClaimable(
        uint256 baseTokenLidPool,
        uint256 cycles,
        uint256 claimedTokenLidPool
    ) external pure returns (uint256);

    function getTotalXethClaimable(
        uint256 totalIgnited,
        uint256 redeemedXEth,
        uint256 claimedXEth,
        uint256 cycles
    ) external pure returns (uint256);

    function getRedeemValue(uint256 amount, uint256 tokensPerEthWad)
        external
        pure
        returns (uint256);

    function isInsuranceExhausted(
        uint256 currentTime,
        uint256 startTime,
        uint256 insurancePeriod,
        uint256 xEthValue,
        uint256 baseXEth,
        uint256 redeemedXEth,
        bool isUnwound
    ) external pure returns (bool);
}
