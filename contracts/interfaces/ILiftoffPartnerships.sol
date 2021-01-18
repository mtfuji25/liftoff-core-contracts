pragma solidity =0.6.6;

interface ILiftoffPartnerships {
    function setPartner(
        uint256 _ID,
        address _controller,
        string calldata _IPFSConfigHash
    ) external;

    function requestPartnership(
        uint256 _partnerId,
        uint256 _tokenSaleId,
        uint256 _feeBP
    ) external;

    function acceptPartnership(uint256 _tokenSaleId, uint8 _requestId) external;

    function cancelPartnership(uint256 _tokenSaleId, uint8 _requestId) external;

    function addFees(uint256 _tokenSaleId, uint256 _wad) external;

    function getTotalBP(uint256 _tokenSaleId)
        external
        view
        returns (uint256 totalBP);

    function getTokenSalePartnerships(uint256 _tokenSaleId)
        external
        view
        returns (uint8 totalPartnerships, uint256 totalBPForPartnerships);

    function getPartnership(uint256 _tokenSaleId, uint8 _partnershipId)
        external
        view
        returns (
            uint256 partnerId,
            uint256 tokenSaleId,
            uint256 feeBP,
            bool isApproved
        );
}
