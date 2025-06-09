// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/v2/ReviewSystem.sol";
import "../src/v2/GigMarketplace.sol";
import "../src/v2/Registry.sol";
import "../src/v2/PaymentProcessor.sol";
import "../src/v2/Token.sol";
import "../src/v2/CraftCoin.sol";

contract ReviewSystemTest is Test {
    Registry registry;
    Token token;
    PaymentProcessor paymentProcessor;
    GigMarketplace gigMarketplace;
    ReviewSystem reviewSystem;
    CraftCoin craftCoin;

    address relayer = address(0x1);
    address client = address(0x2);
    address artisan = address(0x3);

    bytes32 databaseId = keccak256("databaseId");

    function setUp() public {
        registry = new Registry(relayer);
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        craftCoin = new CraftCoin(relayer, address(registry));
        gigMarketplace = new GigMarketplace(relayer, address(registry), address(paymentProcessor), address(craftCoin));
        reviewSystem = new ReviewSystem(relayer, address(registry), address(gigMarketplace));

        vm.startPrank(client);
        registry.registerAsClient("clientIpfs");
        token.claim();
        token.approve(address(paymentProcessor), 1000 * 10 ** 6);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(artisan);
        registry.registerAsArtisan("artisanIpfs");
        craftCoin.mint();
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        craftCoin.approve(address(gigMarketplace), requiredCFT);
        gigMarketplace.applyForGig(databaseId);
        vm.stopPrank();
        
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
