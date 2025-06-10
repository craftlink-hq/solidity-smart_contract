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

    address relayer = vm.addr(1);
    address client = vm.addr(2);
    address client2 = vm.addr(3);
    address artisan = vm.addr(4);
    uint256 artisanPrivateKey = 4;
    address artisan2 = vm.addr(5);
    uint256 artisan2PrivateKey = 5;

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

        vm.startPrank(relayer);
        registry.registerAsArtisanFor(artisan, "artisanIpfs");
        craftCoin.mintFor(artisan);

        registry.registerAsArtisanFor(artisan2, "artisan2Ipfs");
        craftCoin.mintFor(artisan2);
        vm.stopPrank();
    }

    function generatePermitSignature(
        address _artisan,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint256 _artisanPrivateKey
    ) internal view returns (uint8 _v, bytes32 _r, bytes32 _s) {
        uint256 nonce = craftCoin.nonces(artisan);
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
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        (_v, _r, _s) = vm.sign(_artisanPrivateKey, digest);
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

        (address gigClient1,, uint256 payment1Id,,,,) = gigMarketplace.getGigInfo(keccak256("databaseId1"));
        (address gigClient2,, uint256 payment2Id,,,,) = gigMarketplace.getGigInfo(keccak256("databaseId2"));
        assertEq(gigClient1, client);
        assertEq(payment1Id, 1);
        assertEq(gigClient2, client2);
        assertEq(payment2Id, 2);
    }

    function testUpdateGigInfo() public {
        vm.startPrank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);
        gigMarketplace.updateGigInfo(databaseId, keccak256("newRootHash"));
        vm.stopPrank();

        (,,, bytes32 rootHash,,,) = gigMarketplace.getGigInfo(databaseId);
        assertEq(rootHash, keccak256("newRootHash"));
    }

    function testCannotUpdateGigInfoAsNotGigOwner() public {
        vm.startPrank(artisan);
        vm.expectRevert("Not gig owner");
        gigMarketplace.updateGigInfo(databaseId, keccak256("newRootHash"));
        vm.stopPrank();
    }

    // TODO: Client should not be able to update gig info (except for gig amount) after hiring an artisan
    // This will likely be handled in the backend

    function testCannotUpdateCompletedGig() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);

        vm.startPrank(relayer);
        uint256 deadline = block.timestamp + 1 days;
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey);
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.prank(client);
        gigMarketplace.hireArtisan(databaseId, artisan);

        vm.prank(artisan);
        gigMarketplace.markComplete(databaseId);

        vm.startPrank(client);
        gigMarketplace.confirmComplete(databaseId);
        vm.expectRevert("Gig finished");
        gigMarketplace.updateGigInfo(databaseId, keccak256("newRootHash"));
        vm.stopPrank();
    }

    function testCannotUpdateClosedGig() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);

        vm.startPrank(relayer);
        uint256 deadline = block.timestamp + 1 days;
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey);
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.startPrank(client);
        gigMarketplace.closeGig(databaseId);
        vm.expectRevert("Gig finished");
        gigMarketplace.updateGigInfo(databaseId, keccak256("newRootHash"));
        vm.stopPrank();
    }

    function testGetLatestRootHash() public {
        vm.startPrank(relayer);
        gigMarketplace.createGigFor(client, keccak256("rootHash1"), keccak256("databaseId1"), 100 * 10 ** 6);
        gigMarketplace.createGigFor(client2, keccak256("rootHash2"), keccak256("databaseId2"), 200 * 10 ** 6);
        gigMarketplace.createGigFor(client, keccak256("rootHash3"), keccak256("databaseId3"), 300 * 10 ** 6);
        gigMarketplace.createGigFor(client2, keccak256("rootHash4"), keccak256("databaseId4"), 400 * 10 ** 6);
        vm.stopPrank();

        bytes32 latestRootHash = gigMarketplace.getLatestRootHash();
        assertEq(latestRootHash, keccak256("rootHash4"));
    }

    function testApplyForGig() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);

        vm.startPrank(relayer);
        uint256 deadline = block.timestamp + 1 days;
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey);
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        address[] memory applicants = gigMarketplace.getGigApplicants(databaseId);
        assertEq(applicants[0], artisan);
    }

    function testCannotApplyForInvalidGigId() public {
        vm.startPrank(relayer);
        uint256 deadline = block.timestamp + 1 days;
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey);
        vm.expectRevert("Invalid gig ID");
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();
    }

    // TODO: Ensure to test that an unverified artisan cannot apply for a gig

    function testCannotApplyToClosedGig() public {
        vm.startPrank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);
        gigMarketplace.closeGig(databaseId);
        vm.stopPrank();

        vm.startPrank(relayer);
        uint256 deadline = block.timestamp + 1 days;
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey);
        vm.expectRevert("Gig is closed");
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();
    }

    function testCannotApplyToGigWithHiredArtisan() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);

        vm.startPrank(relayer);
        uint256 deadline = block.timestamp + 1 days;
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey);
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.prank(client);
        gigMarketplace.hireArtisan(databaseId, artisan);

        vm.startPrank(relayer);
        uint256 deadline2 = block.timestamp + 1 days;
        uint256 requiredCFT2 = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignature(artisan2, address(gigMarketplace), requiredCFT2, deadline2, artisan2PrivateKey);
        vm.expectRevert("Artisan already hired");
        gigMarketplace.applyForGigFor(artisan2, databaseId, deadline, v2, r2, s2);
        vm.stopPrank();
    }

    function testCannotApplyForSameGigAgain() public {
        vm.prank(client);
        gigMarketplace.createGig(keccak256("rootHash"), databaseId, 100 * 10 ** 6);

        vm.startPrank(relayer);
        uint256 deadline = block.timestamp + 1 days;
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey);
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        vm.expectRevert("Already applied");
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();
    }

    // function testPaidApplyForGig() public {
    //     vm.prank(relayer);
    //     gigMarketplace.createGigFor(client, keccak256("rootHash"), databaseId, 100 * 10 ** 6);

    //     vm.startPrank(artisan);
    //     uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
    //     craftCoin.approve(address(gigMarketplace), requiredCFT);
    //     gigMarketplace.applyForGig(databaseId);
    //     vm.stopPrank();

    //     address[] memory applicants = gigMarketplace.getGigApplicants(databaseId);
    //     assertEq(applicants[0], artisan);
    // }
}
