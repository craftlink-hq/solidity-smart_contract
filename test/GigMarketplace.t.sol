// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/v2/GigMarketplace.sol";
import "../src/v2/Registry.sol";
import "../src/v2/PaymentProcessor.sol";
import "../src/v2/Token.sol";

contract GigMarketplaceTest is Test {
    Registry registry;
    Token token;
    PaymentProcessor paymentProcessor;
    GigMarketplace gigMarketplace;
    address relayer = address(0x1);
    address client = address(0x2);
    address artisan = address(0x3);
    bytes32 databaseId = keccak256("databaseId");

    function setUp() public {
        registry = new Registry(relayer);
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        gigMarketplace = new GigMarketplace(relayer, address(registry), address(paymentProcessor));
        vm.prank(client);
        registry.registerAsClient("clientIpfs");
        vm.prank(artisan);
        registry.registerAsArtisan("artisanIpfs");
        vm.prank(client);
        token.claim();
        vm.prank(client);
        token.approve(address(paymentProcessor), 1000 * 10**6);
    }

    function testCreateGig() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10**6);
        (address gigClient,,,,,,) = gigMarketplace.getGigInfo(databaseId);
        assertEq(gigClient, client);
    }

    function testApplyForGig() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10**6);
        vm.prank(artisan);
        gigMarketplace.applyForGig(databaseId);
        address[] memory applicants = gigMarketplace.getGigApplicants(databaseId);
        assertEq(applicants[0], artisan);
    }
}