pragma solidity =0.6.6;

import "./interfaces/ILiftoffPartnerships.sol";
import "./interfaces/ILiftoffSettings.sol";
import "./interfaces/ILiftoffEngine.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LiftoffPartnerships is
    ILiftoffPartnerships,
    OwnableUpgradeable
{
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
        uint256 totalFeesClaimed;
        uint256 totalFees;
        bool isApproved;
    }

    ILiftoffSettings public liftoffSettings;

    modifier isLiftoffInsurance() {
        require(liftoffSettings.getLiftoffInsurance() == _msgSender(), "Sender must be LiftoffInsurance");
        _;
    }

    modifier isOwnerOrTokenSaleDev(uint256 _tokenSaleId) {
        (address projectDev) =
            ILiftoffEngine(liftoffSettings.getLiftoffEngine()).getTokenSaleForPartnerships(_tokenSaleId);
        require(_msgSender() == owner() || _msgSender() == projectDev, "Sender must be Owner or TokenSaleDev");
        _;
    }

    modifier isOwnerOrPartnerController() {
        bool isOwnerOrPartner = false;
        if (_msgSender() == owner()) {
            isOwnerOrPartner = true;
        } else {
            for (uint256 i = 0; i < totalPartnerControllers; i++) {
                if (_msgSender() == partnerController[i]) {
                    isOwnerOrPartner = true;
                    break;
                }
            }
        }
        require(isOwnerOrPartner, "Sender must be Owner or PartnerController");
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

    function setPartner(uint8 _ID, address _controller, string calldata _IPFSConfigHash)
        external
        override
        onlyOwner
    {
        if (partnerController[_ID] == address(0x0))
            totalPartnerControllers++;
        else if (_controller == address(0x0)) {
            delete partnerController[_ID];
            delete partnerIPFSConfigHash[_ID];
        } else {
            partnerController[_ID] = _controller;
            partnerIPFSConfigHash[_ID] = _IPFSConfigHash;
        }
    }

    function requestPartnership(
        uint8 _partnerId,
        uint256 _tokenSaleId,
        uint256 _feeBP,
        uint256 _totalFeesClaimed,
        uint256 _totalFees
    ) external override isOwnerOrTokenSaleDev(_tokenSaleId) {
        TokenSalePartnerships storage partnerships = tokenSalePartnerships[_tokenSaleId];
        partnerships.totalPartnerships++;
        partnerships.totalBPForPartners += _feeBP;
        partnerships.partnershipRequests[_partnerId] = Partnership({
            partnerId: _partnerId,
            tokenSaleId: _tokenSaleId,
            feeBP: _feeBP,
            totalFeesClaimed: _totalFeesClaimed,
            totalFees: _totalFees,
            isApproved: false
        });
    }

    function acceptPartnership(
        uint256 _tokenSaleId,
        uint8 _requestId
    ) external override isOwnerOrPartnerController {
        TokenSalePartnerships storage partnerships = tokenSalePartnerships[_tokenSaleId];
        Partnership storage partnership = partnerships.partnershipRequests[_requestId];
        partnership.isApproved = true;
    }

    function cancelPartnership(
        uint _tokenSaleId,
        uint8 _requestId
    ) external override isOwnerOrPartnerController {
        TokenSalePartnerships storage partnerships = tokenSalePartnerships[_tokenSaleId];
        Partnership storage partnership = partnerships.partnershipRequests[_requestId];
        partnership.isApproved = false;
    }

    function addFees(
        uint256 _tokenSaleId,
        uint256 _wad
    ) external override isLiftoffInsurance {

    }

    function claimFees(
        uint256 _tokenSaleId,
        uint8 _requestId
    ) external override {

    }

    function getTotalBP(uint256 _tokenSaleId) external override view returns (uint256 totalBP) {
        totalBP = tokenSalePartnerships[_tokenSaleId].totalBPForPartners;
    }

    function getTokenSalePartnerships(uint256 _tokenSaleId)
        external
        override
        view
        returns (uint8 totalPartnerships, uint256 totalBPForParnterships)
    {
        TokenSalePartnerships storage partnerships = tokenSalePartnerships[_tokenSaleId];
        totalPartnerships = partnerships.totalPartnerships;
        totalBPForParnterships = partnerships.totalBPForPartners;
    }

    function getPartnership(uint256 _tokenSaleId, uint8 _partnershipId) external override view returns (
        uint256 partnerId,
        uint256 tokenSaleId,
        uint256 feeBP,
        uint256 totalFeesClaimed,
        uint256 totalFees,
        bool isApproved
    ) {
        TokenSalePartnerships storage partnerships = tokenSalePartnerships[_tokenSaleId];
        Partnership storage partnership = partnerships.partnershipRequests[_partnershipId];
        partnerId = partnership.partnerId;
        tokenSaleId = partnership.tokenSaleId;
        feeBP = partnership.feeBP;
        totalFeesClaimed = partnership.partnerId;
        totalFees = partnership.partnerId;
        isApproved = partnership.isApproved;
    }
}