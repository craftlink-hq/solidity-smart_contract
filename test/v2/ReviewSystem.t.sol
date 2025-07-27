// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v2/ReviewSystem.sol";
import "../../src/v2/GigMarketplace.sol";
import "../../src/v2/Registry.sol";
import "../../src/v2/PaymentProcessor.sol";
import "../../src/v2/Token.sol";
import "../../src/v2/CraftCoin.sol";

contract ReviewSystemTest is Test {
    Registry registry;
    Token token;
    PaymentProcessor paymentProcessor;
    GigMarketplace gigMarketplace;
    ReviewSystem reviewSystem;
    CraftCoin craftCoin;

    address relayer = vm.addr(1);
    address client = vm.addr(2);
    uint256 clientPrivateKey = 2;
    address client2 = vm.addr(3);
    uint256 client2PrivateKey = 3;
    address artisan = vm.addr(4);
    uint256 artisanPrivateKey = 4;
    address artisan2 = vm.addr(5);
    uint256 artisan2PrivateKey = 5;

    bytes32 databaseId = keccak256("databaseId");
    bytes32 databaseId2 = keccak256("databaseId2");

    bytes32 rootHash = keccak256("rootHash");
    bytes32 rootHash2 = keccak256("rootHash2");

    uint256 deadline = block.timestamp + 1 days;

    function setUp() public {
        registry = new Registry(relayer);
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        craftCoin = new CraftCoin(relayer, address(registry));
        gigMarketplace = new GigMarketplace(relayer, address(registry), address(paymentProcessor), address(craftCoin));
        reviewSystem = new ReviewSystem(relayer, address(registry), address(gigMarketplace));

        vm.startPrank(relayer);
        registry.registerAsClientFor(client, "clientIpfs");
        token.claimFor(client);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);

        registry.registerAsArtisanFor(artisan, "artisanIpfs");
        craftCoin.mintFor(artisan);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v_, r_, s_);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        gigMarketplace.markCompleteFor(artisan, databaseId);
        gigMarketplace.confirmCompleteFor(client, databaseId);
        vm.stopPrank();
    }

    function generatePermitSignatureForClient(
        address _client,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint256 _clientPrivateKey
    ) internal view returns (uint8 _v, bytes32 _r, bytes32 _s) {
        uint256 nonce = token.nonces(_client);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                _client,
                _spender,
                _value,
                nonce,
                _deadline
            )
        );
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (_v, _r, _s) = vm.sign(_clientPrivateKey, digest);
    }

    function generatePermitSignatureForArtisan(
        address _artisan,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint256 _artisanPrivateKey
    ) internal view returns (uint8 _v, bytes32 _r, bytes32 _s) {
        uint256 nonce = craftCoin.nonces(_artisan);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                _artisan,
                _spender,
                _value,
                nonce,
                _deadline
            )
        );
        bytes32 domainSeparator = craftCoin.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (_v, _r, _s) = vm.sign(_artisanPrivateKey, digest);
    }

    function testClientSubmitReview() public {
        vm.prank(relayer);
        reviewSystem.clientSubmitReviewFor(client, databaseId, 4, "commentHash");
        ReviewSystem.ReviewInfo[] memory reviews = reviewSystem.getArtisanReviewInfos(artisan);
        assertEq(reviews[0].rating, 4);
    }

    function testClientCannotSubmitOutOfRangeRating() public {
        vm.prank(relayer);
        vm.expectRevert("Rating must be between 1 and 5");
        reviewSystem.clientSubmitReviewFor(client, databaseId, 6, "commentHash");
    }

    function testClientCannotSubmitReviewForNonExistentGig() public {
        vm.prank(relayer);
        vm.expectRevert("Invalid gig ID");
        reviewSystem.clientSubmitReviewFor(client, databaseId2, 5, "commentHash");
    }

    function testClientCannotSubmitReviewForUncompletedGig1() public {
        vm.startPrank(relayer);
        registry.registerAsClientFor(client2, "clientIpfs");
        token.claimFor(client2);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 100 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);

        registry.registerAsArtisanFor(artisan2, "artisanIpfs");
        craftCoin.mintFor(artisan2);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForArtisan(
            artisan2, address(gigMarketplace), requiredCFT, deadline, artisan2PrivateKey
        );
        gigMarketplace.applyForGigFor(artisan2, databaseId, deadline, v_, r_, s_);

        gigMarketplace.hireArtisanFor(client2, databaseId, artisan2);

        vm.expectRevert("Gig must be completed before submitting a review");
        reviewSystem.clientSubmitReviewFor(client2, databaseId, 5, "commentHash");
        vm.stopPrank();
    }

    function testClientCannotSubmitReviewForUncompletedGig2() public {
        vm.startPrank(relayer);
        registry.registerAsClientFor(client2, "clientIpfs");
        token.claimFor(client2);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 100 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);

        registry.registerAsArtisanFor(artisan2, "artisanIpfs");
        craftCoin.mintFor(artisan2);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForArtisan(
            artisan2, address(gigMarketplace), requiredCFT, deadline, artisan2PrivateKey
        );
        gigMarketplace.applyForGigFor(artisan2, databaseId, deadline, v_, r_, s_);

        gigMarketplace.hireArtisanFor(client2, databaseId, artisan2);
        gigMarketplace.markCompleteFor(artisan2, databaseId);

        vm.expectRevert("Gig must be completed before submitting a review");
        reviewSystem.clientSubmitReviewFor(client2, databaseId, 5, "commentHash");
        vm.stopPrank();
    }

    function testNotClientCannotSubmitReview() public {
        vm.prank(relayer);
        vm.expectRevert("Only the gig client can submit a review");
        reviewSystem.clientSubmitReviewFor(client2, databaseId, 5, "commentHash");
    }

    // Uncomment this test if you want to test the closed gig review functionality
    // For now this can't be tested as it checks for completed before closed
    // ... and a closed gig cannot be completed.

    // function testCannotReviewClosedGig() public {
    //     vm.startPrank(relayer);
    //     registry.registerAsClientFor(client2, "clientIpfs");
    //     token.claimFor(client2);
    //     (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
    //         client2, address(paymentProcessor), 100 * 10 ** 6, deadline, client2PrivateKey
    //     );
    //     gigMarketplace.createGigFor(client2, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);

    //     registry.registerAsArtisanFor(artisan2, "artisanIpfs");
    //     craftCoin.mintFor(artisan2);
    //     uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
    //     (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForArtisan(
    //         artisan2, address(gigMarketplace), requiredCFT, deadline, artisan2PrivateKey
    //     );
    //     gigMarketplace.applyForGigFor(artisan2, databaseId, deadline, v_, r_, s_);
    //     vm.stopPrank();

    //     vm.prank(client2);
    //     gigMarketplace.closeGig(databaseId);

    //     vm.prank(relayer);
    //     vm.expectRevert("Cannot review a closed gig");
    //     reviewSystem.clientSubmitReviewFor(client2, databaseId, 5, "commentHash");
    // }

    function testArtisanSubmitReview() public {
        vm.prank(relayer);
        reviewSystem.artisanSubmitReviewFor(artisan, databaseId, 5, "commentHash");
        ReviewSystem.ReviewInfo[] memory reviews = reviewSystem.getClientReviewInfos(client);
        assertEq(reviews[0].rating, 5);
    }

    function testArtisanCannotSubmitOutOfRangeRating() public {
        vm.prank(relayer);
        vm.expectRevert("Rating must be between 1 and 5");
        reviewSystem.artisanSubmitReviewFor(artisan, databaseId, 0, "commentHash");
    }

    function testArtisanCannotSubmitReviewForNonExistentGig() public {
        vm.prank(relayer);
        vm.expectRevert("Invalid gig ID");
        reviewSystem.artisanSubmitReviewFor(artisan, databaseId2, 5, "commentHash");
    }

    function testArtisanCannotSubmitReviewForUncompletedGig1() public {
        vm.startPrank(relayer);
        registry.registerAsClientFor(client2, "clientIpfs");
        token.claimFor(client2);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 100 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);

        registry.registerAsArtisanFor(artisan2, "artisanIpfs");
        craftCoin.mintFor(artisan2);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForArtisan(
            artisan2, address(gigMarketplace), requiredCFT, deadline, artisan2PrivateKey
        );
        gigMarketplace.applyForGigFor(artisan2, databaseId, deadline, v_, r_, s_);

        gigMarketplace.hireArtisanFor(client2, databaseId, artisan2);

        vm.expectRevert("Gig must be completed before submitting a review");
        reviewSystem.artisanSubmitReviewFor(artisan2, databaseId, 5, "commentHash");
        vm.stopPrank();
    }

    function testArtisanCannotSubmitReviewForUncompletedGig2() public {
        vm.startPrank(relayer);
        registry.registerAsClientFor(client2, "clientIpfs");
        token.claimFor(client2);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 100 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);

        registry.registerAsArtisanFor(artisan2, "artisanIpfs");
        craftCoin.mintFor(artisan2);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForArtisan(
            artisan2, address(gigMarketplace), requiredCFT, deadline, artisan2PrivateKey
        );
        gigMarketplace.applyForGigFor(artisan2, databaseId, deadline, v_, r_, s_);

        gigMarketplace.hireArtisanFor(client2, databaseId, artisan2);
        gigMarketplace.markCompleteFor(artisan2, databaseId);

        vm.expectRevert("Gig must be completed before submitting a review");
        reviewSystem.artisanSubmitReviewFor(artisan2, databaseId, 5, "commentHash");
        vm.stopPrank();
    }

    function testNotArtisanCannotSubmitReview() public {
        vm.prank(relayer);
        vm.expectRevert("Only the hired artisan can submit a client review");
        reviewSystem.artisanSubmitReviewFor(client2, databaseId, 5, "commentHash");
    }

    function testGetArtisanReviewInfos() public {
        vm.prank(relayer);
        reviewSystem.clientSubmitReviewFor(client, databaseId, 4, "commentHash");
        ReviewSystem.ReviewInfo[] memory reviews = reviewSystem.getArtisanReviewInfos(artisan);
        assertEq(reviews.length, 1);
        assertEq(reviews[0].reviewer, client);
        assertEq(reviews[0].rating, 4);
        assertEq(reviews[0].commentHash, "commentHash");
    }

    function testGetClientReviewInfos() public {
        vm.prank(relayer);
        reviewSystem.artisanSubmitReviewFor(artisan, databaseId, 5, "commentHash");
        ReviewSystem.ReviewInfo[] memory reviews = reviewSystem.getClientReviewInfos(client);
        assertEq(reviews.length, 1);
        assertEq(reviews[0].reviewer, artisan);
        assertEq(reviews[0].rating, 5);
        assertEq(reviews[0].commentHash, "commentHash");
    }

    function testGetArtisanReviews() public {
        vm.prank(relayer);
        reviewSystem.clientSubmitReviewFor(client, databaseId, 4, "commentHash");
        string[] memory comments = reviewSystem.getArtisanReviews(artisan);
        assertEq(comments.length, 1);
        assertEq(comments[0], "commentHash");
    }

    function testGetClientReviews() public {
        vm.prank(relayer);
        reviewSystem.artisanSubmitReviewFor(artisan, databaseId, 5, "commentHash");
        string[] memory comments = reviewSystem.getClientReviews(client);
        assertEq(comments.length, 1);
        assertEq(comments[0], "commentHash");
    }

    function testGetArtisanAverageRating() public {
        vm.prank(relayer);
        reviewSystem.clientSubmitReviewFor(client, databaseId, 4, "commentHash");
        uint256 averageRating = reviewSystem.getArtisanAverageRating(artisan);
        assertEq(averageRating, 4);
    }

    function testGetArtisanAverageRatingNoReviews() public view {
        uint256 averageRating = reviewSystem.getArtisanAverageRating(artisan2);
        assertEq(averageRating, 0);
    }

    function testGetClientAverageRating() public {
        vm.prank(relayer);
        reviewSystem.artisanSubmitReviewFor(artisan, databaseId, 5, "commentHash");
        uint256 averageRating = reviewSystem.getClientAverageRating(client);
        assertEq(averageRating, 5);
    }

    function testGetClientAverageRatingNoReviews() public view {
        uint256 averageRating = reviewSystem.getClientAverageRating(client2);
        assertEq(averageRating, 0);
    }
}
