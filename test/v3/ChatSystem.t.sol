// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v3/ChatSystem.sol";
import "../../src/v3/GigMarketplace.sol";
import "../../src/v3/Registry.sol";
import "../../src/v3/PaymentProcessor.sol";
import "../../src/v3/Token.sol";
import "../../src/v3/CraftCoin.sol";

contract ChatSystemTest is Test {
    Registry registry;
    Token token;
    PaymentProcessor paymentProcessor;
    GigMarketplace gigMarketplace;
    ChatSystem chatSystem;
    CraftCoin craftCoin;

    address relayer = address(0x1);
    address client = address(0x2);
    address artisan = address(0x3);
    address artisan2 = address(0x4);

    bytes32 databaseId = keccak256("databaseId");
    bytes32 conversationId = keccak256("conversationId");

    function setUp() public {
        registry = new Registry(relayer);
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        craftCoin = new CraftCoin(relayer, address(registry));
        gigMarketplace = new GigMarketplace(relayer, address(registry), address(paymentProcessor), address(craftCoin));
        chatSystem = new ChatSystem(address(gigMarketplace));

        vm.startPrank(relayer);
        registry.registerAsClientFor(client, "clientIpfs");
        token.claimFor(client);
        token.approveFor(client, address(paymentProcessor), 1000 * 10 ** 6);
        gigMarketplace.createGigFor(client, keccak256("rootHash"), databaseId, 100 * 10 ** 6);

        registry.registerAsArtisanFor(artisan, "artisanIpfs");
        craftCoin.mintFor(artisan);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        craftCoin.approveFor(artisan, address(gigMarketplace), requiredCFT);
        gigMarketplace.applyForGigFor(artisan, databaseId);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        vm.stopPrank();
    }

    function testStartConversation() public {
        vm.prank(relayer);
        chatSystem.startConversationFor(client, conversationId, databaseId, keccak256("initialHash"));
        (bytes32 rootHash, bool isActive) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("initialHash"));
        assertTrue(isActive);
    }

    function testStartConversationAsArtisan() public {
        vm.prank(relayer);
        chatSystem.startConversationFor(artisan, conversationId, databaseId, keccak256("initialHash"));
        (bytes32 rootHash, bool isActive) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("initialHash"));
        assertTrue(isActive);
    }

    function testStartConversationUnauthorized() public {
        vm.expectRevert("Not authorized");
        chatSystem.startConversationFor(artisan2, conversationId, databaseId, keccak256("initialHash"));
    }

    function testStartConversationAlreadyExists() public {
        vm.prank(relayer);
        chatSystem.startConversationFor(client, conversationId, databaseId, keccak256("initialHash"));

        vm.expectRevert("Already exists");
        vm.prank(client);
        chatSystem.startConversationFor(client, conversationId, databaseId, keccak256("anotherHash"));
    }

    function testUpdateConversation() public {
        vm.prank(relayer);
        chatSystem.startConversationFor(client, conversationId, databaseId, keccak256("initialHash"));
        vm.prank(relayer);
        chatSystem.updateConversationFor(artisan, conversationId, databaseId, keccak256("newHash"));
        (bytes32 rootHash,) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("newHash"));
    }

    function testUpdateConversationAsArtisan() public {
        vm.prank(relayer);
        chatSystem.startConversationFor(client, conversationId, databaseId, keccak256("initialHash"));
        vm.prank(relayer);
        chatSystem.updateConversationFor(artisan, conversationId, databaseId, keccak256("newHash"));
        (bytes32 rootHash,) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("newHash"));
    }

    function testUpdateConversationUnauthorized() public {
        vm.prank(relayer);
        chatSystem.startConversationFor(client, conversationId, databaseId, keccak256("initialHash"));

        vm.expectRevert("Not authorized");
        vm.prank(relayer);
        chatSystem.updateConversationFor(artisan2, conversationId, databaseId, keccak256("newHash"));
    }

    function testUpdateConversationNotActive() public {
        vm.expectRevert("Chat not active");
        vm.prank(relayer);
        chatSystem.updateConversationFor(client, conversationId, databaseId, keccak256("newHash"));
    }

    function testGetConversationDetails() public {
        vm.prank(relayer);
        chatSystem.startConversationFor(client, conversationId, databaseId, keccak256("initialHash"));
        (bytes32 rootHash, bool isActive) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("initialHash"));
        assertTrue(isActive);
    }

    function testIsConversationActive() public {
        vm.prank(relayer);
        chatSystem.startConversationFor(client, conversationId, databaseId, keccak256("initialHash"));
        bool isActive = chatSystem.isConversationActive(conversationId);
        assertTrue(isActive);
    }
}
