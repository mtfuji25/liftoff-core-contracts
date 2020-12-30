pragma solidity =0.6.6;

interface ILiftoffEngine {
    function launchToken(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _totalSupply,
        string calldata _name,
        string calldata _symbol,
        address _projectDev
    ) external returns (uint256 tokenId);

    function igniteEth(uint256 _tokenSaleId) external payable;

    function ignite(
        uint256 _tokenSaleId,
        address _for,
        uint256 _amountXEth
    ) external;

    function claimReward(uint256 _tokenSaleId, address _for) external;

    function spark(uint256 _tokenSaleId) external;

    function claimRefund(uint256 _tokenSaleId, address _for) external;

    function getTokenSale(uint256 _tokenSaleId)
        external
        view
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
        );

    function getTokenSaleForInsurance(uint256 _tokenSaleId)
        external
        view
        returns (
            uint256 totalIgnited,
            uint256 rewardSupply,
            address projectDev,
            address pair,
            address deployed
        );

    function isSparkReady(
        uint256 endTime,
        uint256 totalIgnited,
        uint256 hardCap,
        uint256 softCap,
        bool isSparked
    ) external view returns (bool);

    function isIgniting(
        uint256 startTime,
        uint256 endTime,
        uint256 totalIgnited,
        uint256 hardCap
    ) external view returns (bool);

    function isRefunding(
        uint256 endTime,
        uint256 softCap,
        uint256 totalIgnited
    ) external view returns (bool);

    function getReward(
        uint256 ignited,
        uint256 rewardSupply,
        uint256 totalIgnited
    ) external pure returns (uint256 reward);
}
