// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/v2/GigMarketplace.sol";
import "../src/v2/Registry.sol";
import "../src/v2/PaymentProcessor.sol";
import "../src/v2/Token.sol";
import "../src/v2/CraftCoin.sol";

contract GigMarketplaceTest is Test {
    Registry registry;
    Token token;
    PaymentProcessor paymentProcessor;
    GigMarketplace gigMarketplace;
    CraftCoin craftCoin;

    address relayer = address(0x1);
    address client = address(0x2);
    address client2 = address(0x3);
    address artisan = address(0x4);
    address artisan2 = address(0x5);

    bytes32 databaseId = keccak256("databaseId");

    function setUp() public {
        registry = new Registry(relayer);
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        craftCoin = new CraftCoin(relayer, address(registry));
        gigMarketplace = new GigMarketplace(relayer, address(registry), address(paymentProcessor), address(craftCoin));

        vm.startPrank(client);
        registry.registerAsClient("clientIpfs");
        token.claim();
        token.approve(address(paymentProcessor), 1000 * 10 ** 6);
        vm.stopPrank();
        
        vm.startPrank(client2);
        registry.registerAsClient("client2Ipfs");
        token.claim();
        token.approve(address(paymentProcessor), 1000 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(artisan);
        registry.registerAsArtisan("artisanIpfs");
        craftCoin.mint();
        uint256 artisanBalance = craftCoin.balanceOf(artisan);
        craftCoin.approve(address(gigMarketplace), artisanBalance);
        vm.stopPrank();

        vm.startPrank(artisan2);
        registry.registerAsArtisan("artisan2Ipfs");
        craftCoin.mint();
        uint256 artisan2Balance = craftCoin.balanceOf(artisan2);
        craftCoin.approve(address(gigMarketplace), artisan2Balance);
        vm.stopPrank();
    }

    function testCreateGig() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);
        (address gigClient,,,,,,) = gigMarketplace.getGigInfo(databaseId);
        assertEq(gigClient, client);
    }

    function testCreateGigFor() public {
        vm.prank(relayer);
        gigMarketplace.createGigFor(client, keccak256("rootHash"), databaseId, 100 * 10 ** 6);
        (address gigClient,,,,,,) = gigMarketplace.getGigInfo(databaseId);
        assertEq(gigClient, client);
    }

    function testNonRelayerCannotCreateGigFor() public {
        vm.prank(artisan);
        vm.expectRevert("Caller is not the relayer");
        gigMarketplace.createGigFor(client, keccak256("rootHash"), databaseId, 100 * 10 ** 6);
    }

    function testNonClientCannotCreateGig() public {
        vm.prank(artisan);
        vm.expectRevert("Not a client");
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);
    }

    function testCreateMultipleGigFor() public {
        vm.startPrank(relayer);
        gigMarketplace.createGigFor(client, keccak256("rootHash1"), keccak256("databaseId1"), 100 * 10 ** 6);
        gigMarketplace.createGigFor(client2, keccak256("rootHash2"), keccak256("databaseId2"), 200 * 10 ** 6);
        vm.stopPrank();
        (address gigClient1,,,,,,) = gigMarketplace.getGigInfo(keccak256("databaseId1"));
        (address gigClient2,,,,,,) = gigMarketplace.getGigInfo(keccak256("databaseId2"));
        assertEq(gigClient1, client);
        assertEq(gigClient2, client2);
    }

    function testApplyForGig() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);
        vm.prank(artisan);
        gigMarketplace.applyForGig(databaseId);
        address[] memory applicants = gigMarketplace.getGigApplicants(databaseId);
        assertEq(applicants[0], artisan);
    }
}
