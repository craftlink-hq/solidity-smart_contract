// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v2/ChatSystem.sol";
import "../../src/v2/GigMarketplace.sol";
import "../../src/v2/Registry.sol";
import "../../src/v2/PaymentProcessor.sol";
import "../../src/v2/Token.sol";
import "../../src/v2/CraftCoin.sol";

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

    bytes32 databaseId = keccak256("databaseId");
    bytes32 conversationId = keccak256("conversationId");

    function setUp() public {
        registry = new Registry(relayer);
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        craftCoin = new CraftCoin(relayer, address(registry));
        gigMarketplace = new GigMarketplace(relayer, address(registry), address(paymentProcessor), address(craftCoin));
        chatSystem = new ChatSystem(address(gigMarketplace));

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
        console.log("Required CFT:", requiredCFT);
        craftCoin.approve(address(gigMarketplace), requiredCFT);
        gigMarketplace.applyForGig(databaseId);
        vm.stopPrank();

        vm.prank(client);
        gigMarketplace.hireArtisan(databaseId, artisan);
    }

    function testStartConversation() public {
        vm.prank(client);
        chatSystem.startConversation(conversationId, databaseId, keccak256("initialHash"));
        (bytes32 rootHash, bool isActive) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("initialHash"));
        assertTrue(isActive);
    }

    function testStartConversationAsArtisan() public {
        vm.prank(artisan);
        chatSystem.startConversation(conversationId, databaseId, keccak256("initialHash"));
        (bytes32 rootHash, bool isActive) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("initialHash"));
        assertTrue(isActive);
    }

    function testStartConversationUnauthorized() public {
        vm.expectRevert("Not authorized");
        chatSystem.startConversation(conversationId, databaseId, keccak256("initialHash"));
    }

    function testStartConversationAlreadyExists() public {
        vm.prank(client);
        chatSystem.startConversation(conversationId, databaseId, keccak256("initialHash"));

        vm.expectRevert("Already exists");
        vm.prank(client);
        chatSystem.startConversation(conversationId, databaseId, keccak256("anotherHash"));
    }

    function testUpdateConversation() public {
        vm.prank(client);
        chatSystem.startConversation(conversationId, databaseId, keccak256("initialHash"));
        vm.prank(artisan);
        chatSystem.updateConversation(conversationId, databaseId, keccak256("newHash"));
        (bytes32 rootHash,) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("newHash"));
    }

    function testUpdateConversationAsArtisan() public {
        vm.prank(client);
        chatSystem.startConversation(conversationId, databaseId, keccak256("initialHash"));
        vm.prank(artisan);
        chatSystem.updateConversation(conversationId, databaseId, keccak256("newHash"));
        (bytes32 rootHash,) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("newHash"));
    }

    function testUpdateConversationUnauthorized() public {
        vm.prank(client);
        chatSystem.startConversation(conversationId, databaseId, keccak256("initialHash"));

        vm.expectRevert("Not authorized");
        vm.prank(address(0x4));
        chatSystem.updateConversation(conversationId, databaseId, keccak256("newHash"));
    }

    function testUpdateConversationNotActive() public {
        vm.expectRevert("Chat not active");
        vm.prank(client);
        chatSystem.updateConversation(conversationId, databaseId, keccak256("newHash"));
    }

    function testGetConversationDetails() public {
        vm.prank(client);
        chatSystem.startConversation(conversationId, databaseId, keccak256("initialHash"));
        (bytes32 rootHash, bool isActive) = chatSystem.getConversationDetails(conversationId);
        assertEq(rootHash, keccak256("initialHash"));
        assertTrue(isActive);
    }
}
