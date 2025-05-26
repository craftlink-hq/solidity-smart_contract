// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Registry.sol";
import "./GigMarketplace.sol";

contract ReviewSystem {
    Registry public registry;
    GigMarketplace public gigMarketplace;

    struct ReviewInfo {
        address reviewer;
        address reviewee;
        bytes32 databaseId;
        uint256 rating;
        string commentHash;
        uint256 timestamp;
    }

    mapping(address => ReviewInfo[]) public artisanReviews;

    event ReviewSubmitted(address indexed reviewer, address indexed reviewee, bytes32 indexed databaseId, uint256 rating);

    constructor(address _registryAddress, address _gigMarketplaceAddress) {
        registry = Registry(_registryAddress);
        gigMarketplace = GigMarketplace(_gigMarketplaceAddress);
    }

    function submitReview(bytes32 _databaseId, uint256 _rating, string memory _commentHash) external {
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");

        (address client, address hiredArtisan, , , , bool isCompleted, bool isClosed) = gigMarketplace.getGigInfo(_databaseId);

        require(msg.sender == client, "Only the client can submit a review");
        require(isCompleted, "Gig must be completed before submitting a review");
        require(!isClosed, "Cannot review a closed gig");

        ReviewInfo memory newReview = ReviewInfo({
            reviewer: msg.sender,
            reviewee: hiredArtisan,
            databaseId: _databaseId,
            rating: _rating,
            commentHash: _commentHash,
            timestamp: block.timestamp
        });

        artisanReviews[hiredArtisan].push(newReview);
        emit ReviewSubmitted(msg.sender, hiredArtisan, _databaseId, _rating);
    }

    function getArtisanReviewInfos(address _artisan) external view returns (ReviewInfo[] memory) {
        return artisanReviews[_artisan];
    }

    function getArtisanReviews(address _artisan) external view returns (string[] memory) {
        ReviewInfo[] memory reviews = artisanReviews[_artisan];
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
}