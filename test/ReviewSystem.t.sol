// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/v2/ReviewSystem.sol";
import "../src/v2/GigMarketplace.sol";
import "../src/v2/Registry.sol";
import "../src/v2/PaymentProcessor.sol";
import "../src/v2/Token.sol";

contract ReviewSystemTest is Test {
    Registry registry;
    Token token;
    PaymentProcessor paymentProcessor;
    GigMarketplace gigMarketplace;
    ReviewSystem reviewSystem;
    address relayer = address(0x1);
    address client = address(0x2);
    address artisan = address(0x3);
    bytes32 databaseId = keccak256("databaseId");

    function setUp() public {
        registry = new Registry(relayer);
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        gigMarketplace = new GigMarketplace(relayer, address(registry), address(paymentProcessor));
        reviewSystem = new ReviewSystem(relayer, address(registry), address(gigMarketplace));
        vm.prank(client);
        registry.registerAsClient("clientIpfs");
        vm.prank(artisan);
        registry.registerAsArtisan("artisanIpfs");
        vm.prank(client);
        token.claim();
        vm.prank(client);
        token.approve(address(paymentProcessor), 1000 * 10**6);
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10**6);
        vm.prank(artisan);
        gigMarketplace.applyForGig(databaseId);
        vm.prank(client);
        gigMarketplace.hireArtisan(databaseId, artisan);
        vm.prank(artisan);
        gigMarketplace.markComplete(databaseId);
        vm.prank(client);
        gigMarketplace.confirmComplete(databaseId);
    }

    function testClientSubmitReview() public {
        vm.prank(client);
        reviewSystem.clientSubmitReview(databaseId, 4, "commentHash");
        ReviewSystem.ReviewInfo[] memory reviews = reviewSystem.getArtisanReviewInfos(artisan);
        assertEq(reviews[0].rating, 4);
    }
}