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
        uint256 claimedXEth,
        bool isUnwound
    ) external pure returns (bool);

    function getTokenInsuranceUints(uint256 _tokenSaleId)
        external
        view
        returns (
            uint256 startTime,
            uint256 totalIgnited,
            uint256 tokensPerEthWad,
            uint256 baseXEth,
            uint256 baseTokenLidPool,
            uint256 redeemedXEth,
            uint256 claimedXEth,
            uint256 claimedTokenLidPool
        );

    function getTokenInsuranceOthers(uint256 _tokenSaleId)
        external
        view
        returns (
            address pair,
            address deployed,
            address projectDev,
            bool isUnwound,
            bool hasBaseFeeClaimed
        );
    function increaseInsuranceBonus(uint256 tokenId, address from, uint256 wad) external;
    function decreaseInsuranceBonus(uint256 tokenId, address to, uint256 wad) external;
}
