// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IRegistry.sol";
import "./interfaces/IGigMarketplace.sol";

contract ReviewSystem {
    IRegistry public registry;
    IGigMarketplace public gigMarketplace;

    struct ReviewInfo {
        address reviewer;
        address reviewee;
        bytes32 databaseId;
        uint256 rating;
        string commentHash;
        uint256 timestamp;
    }

    mapping(address => ReviewInfo[]) public artisanReviews;
    mapping(address => ReviewInfo[]) public clientReviews;
    address public immutable relayer;

    event ReviewSubmittedByArtisan(
        address indexed reviewer, address indexed reviewee, bytes32 indexed databaseId, uint256 rating
    );

    event ReviewSubmittedByClient(
        address indexed reviewer, address indexed reviewee, bytes32 indexed databaseId, uint256 rating
    );

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Caller is not the relayer");
        _;
    }

    constructor(address _relayer, address _registryAddress, address _gigMarketplaceAddress) {
        relayer = _relayer;
        registry = IRegistry(_registryAddress);
        gigMarketplace = IGigMarketplace(_gigMarketplaceAddress);
    }

    function clientSubmitReviewFor(address _reviewer, bytes32 _databaseId, uint256 _rating, string memory _commentHash)
        external
        onlyRelayer
    {
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");

        (address client, address hiredArtisan,,,, bool isCompleted, bool isClosed) =
            gigMarketplace.getGigInfo(_databaseId);

        require(_reviewer == client, "Only the gig client can submit a review");
        require(isCompleted, "Gig must be completed before submitting a review");
        require(!isClosed, "Cannot review a closed gig");

        ReviewInfo memory newReview = ReviewInfo({
            reviewer: _reviewer,
            reviewee: hiredArtisan,
            databaseId: _databaseId,
            rating: _rating,
            commentHash: _commentHash,
            timestamp: block.timestamp
        });

        artisanReviews[hiredArtisan].push(newReview);
        emit ReviewSubmittedByClient(_reviewer, hiredArtisan, _databaseId, _rating);
    }

    function artisanSubmitReviewFor(address reviewer, bytes32 _databaseId, uint256 _rating, string memory _commentHash)
        external
        onlyRelayer
    {
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");

        (address client, address hiredArtisan,,,, bool isCompleted, bool isClosed) =
            gigMarketplace.getGigInfo(_databaseId);

        require(reviewer == hiredArtisan, "Only the hired artisan can submit a client review");
        require(isCompleted, "Gig must be completed before submitting a review");
        require(!isClosed, "Cannot review a closed gig");

        ReviewInfo memory newReview = ReviewInfo({
            reviewer: reviewer,
            reviewee: client,
            databaseId: _databaseId,
            rating: _rating,
            commentHash: _commentHash,
            timestamp: block.timestamp
        });

        clientReviews[client].push(newReview);
        emit ReviewSubmittedByArtisan(reviewer, client, _databaseId, _rating);
    }

    function getArtisanReviewInfos(address _artisan) external view returns (ReviewInfo[] memory) {
        return artisanReviews[_artisan];
    }

    function getClientReviewInfos(address _client) external view returns (ReviewInfo[] memory) {
        return clientReviews[_client];
    }

    function getArtisanReviews(address _artisan) external view returns (string[] memory) {
        ReviewInfo[] memory reviews = artisanReviews[_artisan];
        string[] memory comments = new string[](reviews.length);

        for (uint256 i = 0; i < reviews.length; i++) {
            comments[i] = reviews[i].commentHash;
        }

        return comments;
    }

    function getClientReviews(address _client) external view returns (string[] memory) {
        ReviewInfo[] memory reviews = clientReviews[_client];
        string[] memory comments = new string[](reviews.length);
        for (uint256 i = 0; i < reviews.length; i++) {
            comments[i] = reviews[i].commentHash;
        }
        return comments;
    }

    function getArtisanAverageRating(address _artisan) external view returns (uint256) {
        ReviewInfo[] memory reviews = artisanReviews[_artisan];
        if (reviews.length == 0) {
            return 0;
        }

        uint256 totalRating = 0;
        for (uint256 i = 0; i < reviews.length; i++) {
            totalRating += reviews[i].rating;
        }

        return totalRating / reviews.length;
    }

    function getClientAverageRating(address _client) external view returns (uint256) {
        ReviewInfo[] memory reviews = clientReviews[_client];
        if (reviews.length == 0) return 0;
        uint256 totalRating = 0;
        for (uint256 i = 0; i < reviews.length; i++) {
            totalRating += reviews[i].rating;
        }
        return totalRating / reviews.length;
    }

    function getArtisanReviewCount(address _artisan) external view returns (uint256) {
        return artisanReviews[_artisan].length;
    }

    function getClientReviewCount(address _client) external view returns (uint256) {
        return clientReviews[_client].length;
    }

    function getReviewDetails(address _reviewer, address _reviewee, bytes32 _databaseId)
        external
        view
        returns (ReviewInfo memory)
    {
        ReviewInfo[] storage reviews = artisanReviews[_reviewee];
        for (uint256 i = 0; i < reviews.length; i++) {
            if (reviews[i].reviewer == _reviewer && reviews[i].databaseId == _databaseId) {
                return reviews[i];
            }
        }
        revert("Review not found");
    }
}
