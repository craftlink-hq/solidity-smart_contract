// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IRegistry.sol";
import "./interfaces/IPaymentProcessor.sol";
import "./interfaces/ICraftCoin.sol";

contract GigMarketplace {
    struct GigInfo {
        address client;
        address[] gigApplicants;
        address hiredArtisan;
        uint256 paymentId;
        bytes32 databaseId;
        bytes32 rootHash; // Single root hash for all gig data
        bool artisanComplete;
        bool isCompleted;
        bool isClosed;
    }

    IRegistry public immutable registry;
    IPaymentProcessor public immutable paymentProcessor;
    ICraftCoin public immutable craftCoin;
    address public immutable relayer;

    mapping(uint256 => GigInfo) public gigs;
    mapping(bytes32 => uint256) public indexes; // Inverse mapping of gig indexes by databaseId for quick reference
    uint256 public gigCounter;

    mapping(address => uint256) public clientGigCount;
    mapping(address => uint256) public artisanHiredCount;
    mapping(address => bytes32[]) public artisanAppliedGigs;
    mapping(address => bytes32[]) public clientCreatedGigs;

    event GigCreated(uint256 indexed gigId, address indexed client, bytes32 rootHash);
    event GigApplicationSubmitted(uint256 indexed gigId, address indexed artisan);
    event ArtisanHired(uint256 indexed gigId, address indexed artisan);
    event GigStateUpdated(uint256 indexed gigId, bytes32 newRootHash);
    event ArtisanMarkCompleted(uint256 indexed gigId);
    event ClientConfirmCompleted(uint256 indexed gigId);
    event GigClosed(uint256 indexed gigId);

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Caller is not the relayer");
        _;
    }

    constructor(address _relayer, address _registry, address _paymentProcessor, address _craftCoin) {
        relayer = _relayer;
        registry = IRegistry(_registry);
        paymentProcessor = IPaymentProcessor(_paymentProcessor);
        craftCoin = ICraftCoin(_craftCoin);
    }

    function createGig(bytes32 _rootHash, bytes32 _databaseId, uint256 _budget) external {
        require(registry.isClient(msg.sender), "Not a client");

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
        clientCreatedGigs[msg.sender].push(_databaseId);

        emit GigCreated(gigCounter, msg.sender, _rootHash);
    }

    function createGigFor(
        address _client,
        bytes32 _rootHash,
        bytes32 _databaseId,
        uint256 _budget,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external onlyRelayer {
        require(registry.isClient(_client), "Not a client");

        gigCounter++;
        paymentProcessor.createPaymentFor(_client, _budget, _budget, _deadline, _v, _r, _s);

        gigs[gigCounter] = GigInfo({
            client: _client,
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
        clientCreatedGigs[_client].push(_databaseId);

        emit GigCreated(gigCounter, _client, _rootHash);
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

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(registry.isArtisanVerified(msg.sender), "Unverified artisan");
        require(!gig.isClosed, "Gig is closed");
        require(gig.hiredArtisan == address(0), "Artisan already hired");
        require(!_isApplicant(thisGigId, msg.sender), "Already applied");
        require(gig.client != msg.sender, "Cannot apply to your own gig");

        uint256 requiredCFT = getRequiredCFT(_databaseId);
        craftCoin.burnFor(msg.sender, requiredCFT); // Since there is no restriction on who can burn, we allow the gigContract to burn CFT for the user

        gig.gigApplicants.push(msg.sender);
        artisanAppliedGigs[msg.sender].push(_databaseId);

        emit GigApplicationSubmitted(thisGigId, msg.sender);
    }

    function applyForGigFor(address _artisan, bytes32 _databaseId, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s)
        external
        onlyRelayer
    {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(registry.isArtisanVerified(_artisan), "Unverified artisan");
        require(!gig.isClosed, "Gig is closed");
        require(gig.hiredArtisan == address(0), "Artisan already hired");
        require(!_isApplicant(thisGigId, _artisan), "Already applied");
        require(gig.client != _artisan, "Cannot apply to your own gig");

        uint256 requiredCFT = getRequiredCFT(_databaseId);
        craftCoin.permit(_artisan, address(this), requiredCFT, _deadline, _v, _r, _s);
        craftCoin.burnFor(_artisan, requiredCFT);

        gig.gigApplicants.push(_artisan);
        artisanAppliedGigs[_artisan].push(_databaseId);

        emit GigApplicationSubmitted(thisGigId, _artisan);
    }

    function hireArtisan(bytes32 _databaseId, address _artisan) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(msg.sender == gig.client, "Not gig owner");
        require(gig.hiredArtisan == address(0), "Artisan already hired");
        require(!gig.isClosed, "Gig is closed");
        require(_isApplicant(thisGigId, _artisan), "Not an applicant");

        gig.hiredArtisan = _artisan;
        clientGigCount[gig.client] += 1;
        artisanHiredCount[_artisan] += 1;

        emit ArtisanHired(thisGigId, _artisan);
    }

    function hireArtisanFor(address _client, bytes32 _databaseId, address _artisan) external onlyRelayer {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(_client == gig.client, "Not gig owner");
        require(gig.hiredArtisan == address(0), "Artisan already hired");
        require(!gig.isClosed, "Gig is closed");
        require(_isApplicant(thisGigId, _artisan), "Not an applicant");

        gig.hiredArtisan = _artisan;
        clientGigCount[gig.client] += 1;
        artisanHiredCount[_artisan] += 1;

        emit ArtisanHired(thisGigId, _artisan);
    }

    function markComplete(bytes32 _databaseId) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(msg.sender == gig.hiredArtisan, "Not hired artisan");
        require(!gig.isCompleted && !gig.isClosed, "Gig finished");
        require(!gig.artisanComplete, "Already marked");

        gig.artisanComplete = true;

        emit ArtisanMarkCompleted(thisGigId);
    }

    function markCompleteFor(address _artisan, bytes32 _databaseId) external onlyRelayer {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(_artisan == gig.hiredArtisan, "Not hired artisan");
        require(!gig.isCompleted && !gig.isClosed, "Gig finished");
        require(!gig.artisanComplete, "Already marked");

        gig.artisanComplete = true;
        emit ArtisanMarkCompleted(thisGigId);
    }

    function confirmComplete(bytes32 _databaseId) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(msg.sender == gig.client, "Not gig owner");
        require(gig.artisanComplete && !gig.isCompleted && !gig.isClosed, "Gig not completed || Closed");

        gig.isCompleted = true;

        emit ClientConfirmCompleted(thisGigId);
    }

    function confirmCompleteFor(address _client, bytes32 _databaseId) external onlyRelayer {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(_client == gig.client, "Not gig owner");
        require(gig.artisanComplete && !gig.isCompleted && !gig.isClosed, "Gig not completed || Closed");

        gig.isCompleted = true;
        emit ClientConfirmCompleted(thisGigId);
    }

    function closeGig(bytes32 _databaseId) external {
        uint256 thisGigId = indexes[_databaseId];
        GigInfo storage gig = gigs[thisGigId];

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");
        require(msg.sender == gig.client, "Not gig owner");
        require(gig.hiredArtisan == address(0), "Cannot close active gig");
        require(!gig.isCompleted && !gig.isClosed, "Gig already Completed || Closed");

        gig.isClosed = true;
        paymentProcessor.refundClientFunds(gig.paymentId);

        emit GigClosed(thisGigId);
    }

    function getRequiredCFT(bytes32 _databaseId) public view returns (uint256) {
        uint256 gigId = indexes[_databaseId];
        (, uint256 budget,,) = paymentProcessor.getPaymentDetails(gigs[gigId].paymentId);
        if (budget < 100 * 10 ** 6) return 2 * 10 ** 18; // 2 CFT

        else if (budget < 500 * 10 ** 6) return 5 * 10 ** 18; // 5 CFT

        else return 10 * 10 ** 18; // 10 CFT
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

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");

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

        require(thisGigId <= gigCounter && thisGigId != 0, "Invalid gig ID");

        return gig.gigApplicants;
    }

    function getClientGigCount(address _client) external view returns (uint256) {
        return clientGigCount[_client];
    }

    function getArtisanHiredCount(address _artisan) external view returns (uint256) {
        return artisanHiredCount[_artisan];
    }

    function getArtisanAppliedGigs(address _artisan) external view returns (bytes32[] memory) {
        return artisanAppliedGigs[_artisan];
    }

    function getClientCreatedGigs(address _client) external view returns (bytes32[] memory) {
        return clientCreatedGigs[_client];
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
