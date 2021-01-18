pragma solidity =0.6.6;

import "./interfaces/ILiftoffPartnerships.sol";
import "./interfaces/ILiftoffSettings.sol";
import "./interfaces/ILiftoffEngine.sol";
import "./library/BasisPoints.sol";
import "@lidprotocol/xlock-contracts/contracts/interfaces/IXEth.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

contract LiftoffPartnerships is ILiftoffPartnerships, OwnableUpgradeable {
    using BasisPoints for uint256;
    using SafeMathUpgradeable for uint256;

    uint256 totalPartnerControllers;
    mapping(uint256 => address) public partnerController;
    mapping(uint256 => string) public partnerIPFSConfigHash;
    mapping(uint256 => TokenSalePartnerships) public tokenSalePartnerships;

    struct TokenSalePartnerships {
        uint8 totalPartnerships;
        uint256 totalBPForPartners;
        mapping(uint8 => Partnership) partnershipRequests;
    }

    struct Partnership {
        uint256 partnerId;
        uint256 tokenSaleId;
        uint256 feeBP;
        bool isApproved;
    }

    ILiftoffSettings public liftoffSettings;

    event SetPartner(uint256 ID, address controller, string IPFSConfigHash);
    event RequestPartnership(
        uint256 partnerId,
        uint256 tokenSaleId,
        uint256 feeBP
    );
    event AcceptPartnership(uint256 tokenSaleId, uint8 requestId);
    event CancelPartnership(uint256 tokenSaleId, uint8 requestId);
    event AddFees(uint256 tokenSaleId, uint256 wad);
    event ClaimFees(uint256 tokenSaleId, uint256 feeWad, uint8 requestId);

    modifier onlyBeforeSaleStart(uint256 _tokenSaleId) {
        require(
            ILiftoffEngine(liftoffSettings.getLiftoffEngine())
                .getTokenSaleStartTime(_tokenSaleId) >= now,
            "Sale already started."
        );
        _;
    }

    modifier isLiftoffInsurance() {
        require(
            liftoffSettings.getLiftoffInsurance() == _msgSender(),
            "Sender must be LiftoffInsurance"
        );
        _;
    }

    modifier isOwnerOrTokenSaleDev(uint256 _tokenSaleId) {
        address projectDev =
            ILiftoffEngine(liftoffSettings.getLiftoffEngine())
                .getTokenSaleProjectDev(_tokenSaleId);
        require(
            _msgSender() == owner() || _msgSender() == projectDev,
            "Sender must be Owner or TokenSaleDev"
        );
        _;
    }

    modifier isOwnerOrPartnerController(
        uint256 _tokenSaleId,
        uint8 _requestId
    ) {
        address partner =
            partnerController[
                tokenSalePartnerships[_tokenSaleId].partnershipRequests[
                    _requestId
                ]
                    .partnerId
            ];
        require(
            _msgSender() == owner() || _msgSender() == partner,
            "Sender must be Owner or PartnerController"
        );
        _;
    }

    function initialize(ILiftoffSettings _liftoffSettings)
        external
        initializer
    {
        OwnableUpgradeable.__Ownable_init();
        liftoffSettings = _liftoffSettings;
    }

    function setLiftoffSettings(ILiftoffSettings _liftoffSettings)
        public
        onlyOwner
    {
        liftoffSettings = _liftoffSettings;
    }

    function setPartner(
        uint256 _ID,
        address _controller,
        string calldata _IPFSConfigHash
    ) external override onlyOwner {
        require(_ID <= totalPartnerControllers, "Must increment partnerId.");
        if (_ID == totalPartnerControllers) totalPartnerControllers++;
        if (_controller == address(0x0)) {
            delete partnerController[_ID];
            delete partnerIPFSConfigHash[_ID];
        } else {
            partnerController[_ID] = _controller;
            partnerIPFSConfigHash[_ID] = _IPFSConfigHash;
        }
        emit SetPartner(_ID, _controller, _IPFSConfigHash);
    }

    function requestPartnership(
        uint256 _partnerId,
        uint256 _tokenSaleId,
        uint256 _feeBP
    )
        external
        override
        isOwnerOrTokenSaleDev(_tokenSaleId)
        onlyBeforeSaleStart(_tokenSaleId)
    {
        TokenSalePartnerships storage partnerships =
            tokenSalePartnerships[_tokenSaleId];
        partnerships.partnershipRequests[
            partnerships.totalPartnerships
        ] = Partnership({
            partnerId: _partnerId,
            tokenSaleId: _tokenSaleId,
            feeBP: _feeBP,
            isApproved: false
        });
        require(
            partnerships.totalPartnerships < 15,
            "Cannot have more than 16 total partnerships"
        );
        partnerships.totalPartnerships++;
        emit RequestPartnership(_partnerId, _tokenSaleId, _feeBP);
    }

    function acceptPartnership(uint256 _tokenSaleId, uint8 _requestId)
        external
        override
        isOwnerOrPartnerController(_tokenSaleId, _requestId)
        onlyBeforeSaleStart(_tokenSaleId)
    {
        TokenSalePartnerships storage partnerships =
            tokenSalePartnerships[_tokenSaleId];
        Partnership storage partnership =
            partnerships.partnershipRequests[_requestId];
        partnership.isApproved = true;
        partnerships.totalBPForPartners = partnerships.totalBPForPartners.add(
            partnership.feeBP
        );
        require(
            partnerships.totalBPForPartners <= liftoffSettings.getProjectDevBP()
        );
        emit AcceptPartnership(_tokenSaleId, _requestId);
    }

    function cancelPartnership(uint256 _tokenSaleId, uint8 _requestId)
        external
        override
        isOwnerOrPartnerController(_tokenSaleId, _requestId)
        onlyBeforeSaleStart(_tokenSaleId)
    {
        TokenSalePartnerships storage partnerships =
            tokenSalePartnerships[_tokenSaleId];
        Partnership storage partnership =
            partnerships.partnershipRequests[_requestId];
        partnership.isApproved = false;
        partnerships.totalBPForPartners = partnerships.totalBPForPartners.sub(
            partnership.feeBP
        );
        emit CancelPartnership(_tokenSaleId, _requestId);
    }

    function addFees(uint256 _tokenSaleId, uint256 _wad)
        external
        override
        isLiftoffInsurance
    {
        TokenSalePartnerships storage partnerships =
            tokenSalePartnerships[_tokenSaleId];
        for (uint8 i; i < partnerships.totalPartnerships; i++) {
            Partnership storage request = partnerships.partnershipRequests[i];
            if (request.isApproved) {
                uint256 fee =
                    request.feeBP.mul(_wad).div(
                        partnerships.totalBPForPartners
                    );
                IXEth(liftoffSettings.getXEth()).transfer(
                    partnerController[request.partnerId],
                    fee
                );
                emit ClaimFees(_tokenSaleId, fee, i);
            }
        }
        emit AddFees(_tokenSaleId, _wad);
    }

    function getTotalBP(uint256 _tokenSaleId)
        external
        view
        override
        returns (uint256 totalBP)
    {
        totalBP = tokenSalePartnerships[_tokenSaleId].totalBPForPartners;
    }

    function getTokenSalePartnerships(uint256 _tokenSaleId)
        external
        view
        override
        returns (uint8 totalPartnerships, uint256 totalBPForPartnerships)
    {
        TokenSalePartnerships storage partnerships =
            tokenSalePartnerships[_tokenSaleId];
        totalPartnerships = partnerships.totalPartnerships;
        totalBPForPartnerships = partnerships.totalBPForPartners;
    }

    function getPartnership(uint256 _tokenSaleId, uint8 _partnershipId)
        external
        view
        override
        returns (
            uint256 partnerId,
            uint256 tokenSaleId,
            uint256 feeBP,
            bool isApproved
        )
    {
        TokenSalePartnerships storage partnerships =
            tokenSalePartnerships[_tokenSaleId];
        Partnership storage partnership =
            partnerships.partnershipRequests[_partnershipId];
        partnerId = partnership.partnerId;
        tokenSaleId = partnership.tokenSaleId;
        feeBP = partnership.feeBP;
        isApproved = partnership.isApproved;
    }
}
