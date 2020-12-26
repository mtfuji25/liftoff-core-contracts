pragma solidity =0.6.6;

interface ILiftoffInsurance {
    function register(uint256 _tokenSaleId) external;

    function redeem(uint256 _tokenSaleId, uint256 _amount) external;

    function claim(uint256 _tokenSaleId) external;

    function createInsurance(uint256 _tokenSaleId) external;

    function canCreateInsurance(uint256 _tokenSaleId)
        external
        view
        returns (bool);

    function getTotalTokenClaimable(
        uint256 baseTokenLidPool,
        uint256 cycles,
        uint256 claimedTokenLidPool
    ) external view returns (uint256);

    function getTotalXethClaimable(
        uint256 totalIgnited,
        uint256 redeemedXEth,
        uint256 claimedXEth,
        uint256 cycles
    ) external view returns (uint256);
}
