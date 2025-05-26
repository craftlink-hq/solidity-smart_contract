// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Registry.sol";
import "./PaymentProcessor.sol";

contract GigMarketplace {
    struct GigInfo {
        address client;
        address[] gigApplicants;
        address hiredArtisan;
        uint256 paymentId;
        bytes32 databaseId;
        bytes32 rootHash;   // Single root hash for all gig data
        bool artisanComplete;
        bool isCompleted;
        bool isClosed;
    }

    Registry public registry;
    PaymentProcessor public paymentProcessor;
    
    mapping(uint256 => GigInfo) public gigs;
    mapping(bytes32 => uint256) public indexes; // Inverse mapping of gig indexes by databaseId for quick reference
    uint256 public gigCounter;

    event GigCreated(uint256 indexed gigId, address indexed client, bytes32 rootHash);
    event GigApplicationSubmitted(uint256 indexed gigId, address indexed artisan);
    event ArtisanHired(uint256 indexed gigId, address indexed artisan);
    event GigStateUpdated(uint256 indexed gigId, bytes32 newRootHash);
    event ArtisanMarkCompleted(uint256 indexed gigId);
    event ClientConfirmCompleted(uint256 indexed gigId);
    event GigClosed(uint256 indexed gigId);

    constructor(address _registry, address _paymentProcessor) {
        registry = Registry(_registry);
        paymentProcessor = PaymentProcessor(_paymentProcessor);
    }

    function createGig(bytes32 _rootHash, bytes32 _databaseId, uint256 _budget) external {
        require(registry.userTypes(msg.sender) == Registry.UserType.Client, "Not a client");
        
        gigCounter++;
        paymentProcessor.createPayment(msg.sender, _budget);
        
        gigs[gigCounter] = GigInfo({
            client: msg.sender,
            gigApplicants: new address[](0),
            hiredArtisan: address(0),
            paymentId: paymentProcessor.currentPaymentId(),
            databaseId: _databaseId,
            rootHash: _rootHash,
            artisanComplete: false,
            isCompleted: false,
            isClosed: false
        });

        indexes[_databaseId] = gigCounter;

        emit GigCreated(gigCounter, msg.sender, _rootHash);
    }

    function updateGigInfo(bytes32 _databaseId, bytes32 _newRootHash) external {
        uint256 thisGigId = indexes[_databaseId];

        GigInfo storage gig = gigs[thisGigId];
        require(msg.sender == gig.client, "Not gig owner");
        require(!gig.isCompleted && !gig.isClosed, "Gig finished");
        
        gig.rootHash = _newRootHash;
        emit GigStateUpdated(thisGigId, _newRootHash);
    }

    function getLatestRootHash() external view returns (bytes32) {
        return gigs[gigCounter].rootHash;
    }

    function applyForGig(bytes32 _databaseId) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter, "Invalid gig ID");
        require(registry.isArtisanVerified(msg.sender), "Unverified artisan");
        require(!gig.isClosed, "Gig is closed");
        require(gig.hiredArtisan == address(0), "Artisan already hired");

        gig.gigApplicants.push(msg.sender);
        emit GigApplicationSubmitted(thisGigId, msg.sender);
    }

    function hireArtisan(bytes32 _databaseId, address _artisan) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter, "Invalid gig ID");
        require(msg.sender == gig.client, "Not gig owner");
        require(gig.hiredArtisan == address(0), "Artisan already hired");
        require(!gig.isClosed, "Gig is closed");
        require(_isApplicant(thisGigId, _artisan), "Not an applicant");

        gig.hiredArtisan = _artisan;

        emit ArtisanHired(thisGigId, _artisan);
    }

    function markComplete(bytes32 _databaseId) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter, "Invalid gig ID");
        require(msg.sender == gig.hiredArtisan, "Not hired artisan");
        require(!gig.isCompleted && !gig.isClosed, "Gig finished");
        require(!gig.artisanComplete, "Already marked");

        gig.artisanComplete = true;
        
        emit ArtisanMarkCompleted(thisGigId);
    }

    function confirmComplete(bytes32 _databaseId) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];
        
        require(thisGigId <= gigCounter, "Invalid gig ID");
        require(msg.sender == gig.client, "Not gig owner");
        require(
            gig.artisanComplete && !gig.isCompleted && !gig.isClosed,
            "Gig not completed || Closed"
        );

        gig.isCompleted = true;
        paymentProcessor.releaseArtisanFunds(gig.hiredArtisan, gig.paymentId);
        
        emit ClientConfirmCompleted(thisGigId);
    }

    function closeGig(bytes32 _databaseId) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];
        
        require(thisGigId <= gigCounter, "Invalid gig ID");
        require(msg.sender == gig.client, "Not gig owner");
        require(gig.hiredArtisan == address(0), "Cannot close active gig");
        require(!gig.isCompleted && !gig.isClosed, "Gig already Completed || Closed");

        gig.isClosed = true;
        paymentProcessor.refundClientFunds(gig.paymentId);

        emit GigClosed(thisGigId);
    }

    function getGigInfo(bytes32 _databaseId)
        external
        view
        returns (
            address client,
            address hiredArtisan,
            uint256 paymentId,
            bytes32 rootHash,
            bool artisanComplete,
            bool isCompleted,
            bool isClosed
        )
    {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter, "Invalid gig ID");

        return (
            gig.client,
            gig.hiredArtisan,
            gig.paymentId,
            gig.rootHash,
            gig.artisanComplete,
            gig.isCompleted,
            gig.isClosed
        );
    }

    function getGigApplicants(bytes32 _databaseId) external view returns (address[] memory) {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter, "Invalid gig ID");

        return gig.gigApplicants;
    }

    function _isApplicant(uint256 _gigId, address _artisan) internal view returns (bool) {
        GigInfo storage gig = gigs[_gigId];

        address[] memory applicants = gig.gigApplicants;
        for (uint256 i = 0; i < applicants.length; i++) {
            if (applicants[i] == _artisan) {
                return true;
            }
        }
        return false;
    }
}