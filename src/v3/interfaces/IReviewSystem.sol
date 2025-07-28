// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReviewSystem {
    struct ReviewInfo {
        address reviewer;
        address reviewee;
        bytes32 databaseId;
        uint256 rating;
        string commentHash;
        uint256 timestamp;
    }

    event ReviewSubmittedByArtisan(
        address indexed reviewer, address indexed reviewee, bytes32 indexed databaseId, uint256 rating
    );
    event ReviewSubmittedByClient(
        address indexed reviewer, address indexed reviewee, bytes32 indexed databaseId, uint256 rating
    );

    function clientSubmitReviewFor(address _reviewer, bytes32 _databaseId, uint256 _rating, string memory _commentHash)
        external;
    function artisanSubmitReviewFor(address reviewer, bytes32 _databaseId, uint256 _rating, string memory _commentHash)
        external;
    function getArtisanReviewInfos(address _artisan) external view returns (ReviewInfo[] memory);
    function getClientReviewInfos(address _client) external view returns (ReviewInfo[] memory);
    function getArtisanReviews(address _artisan) external view returns (string[] memory);
    function getClientReviews(address _client) external view returns (string[] memory);
    function getArtisanAverageRating(address _artisan) external view returns (uint256);
    function getClientAverageRating(address _client) external view returns (uint256);
    function getArtisanReviewCount(address _artisan) external view returns (uint256);
    function getClientReviewCount(address _client) external view returns (uint256);
    function getReviewDetails(address _reviewer, address _reviewee, bytes32 _databaseId)
        external
        view
        returns (ReviewInfo memory);
}
