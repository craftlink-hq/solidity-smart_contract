// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGigMarketplace {
    event GigCreated(uint256 indexed gigId, address indexed client, bytes32 rootHash);
    event GigApplicationSubmitted(uint256 indexed gigId, address indexed artisan);
    event ArtisanHired(uint256 indexed gigId, address indexed artisan);
    event GigStateUpdated(uint256 indexed gigId, bytes32 newRootHash);
    event ArtisanMarkCompleted(uint256 indexed gigId);
    event ClientConfirmCompleted(uint256 indexed gigId);
    event GigClosed(uint256 indexed gigId);

    function createGigFor(address _client, bytes32 _rootHash, bytes32 _databaseId, uint256 _budget) external;
    function updateGigInfoFor(address _client, bytes32 _databaseId, bytes32 _newRootHash) external;
    function getLatestRootHash() external view returns (bytes32);
    function applyForGigFor(address _artisan, bytes32 _databaseId) external;
    function hireArtisanFor(address _client, bytes32 _databaseId, address _artisan) external;
    function markCompleteFor(address _artisan, bytes32 _databaseId) external;
    function confirmCompleteFor(address _client, bytes32 _databaseId) external;
    function closeGigFor(address _client, bytes32 _databaseId) external;
    function getRequiredCFT(bytes32 _databaseId) external view returns (uint256);
    function getGigCount() external view returns (uint256);
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
        );
    function getGigApplicants(bytes32 _databaseId) external view returns (address[] memory);
    function getClientGigCount(address _client) external view returns (uint256);
    function getArtisanHiredCount(address _artisan) external view returns (uint256);
    function getArtisanAppliedGigs(address _artisan) external view returns (bytes32[] memory);
    function getClientCreatedGigs(address _client) external view returns (bytes32[] memory);
    function hasAppliedForGig(address _artisan, bytes32 _databaseId) external view returns (bool);
}
