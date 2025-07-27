// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v2/GigMarketplace.sol";
import "../../src/v2/Registry.sol";
import "../../src/v2/PaymentProcessor.sol";
import "../../src/v2/Token.sol";
import "../../src/v2/CraftCoin.sol";

contract GigMarketplaceTest is Test {
    Registry registry;
    Token token;
    PaymentProcessor paymentProcessor;
    GigMarketplace gigMarketplace;
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
    bytes32 databaseId3 = keccak256("databaseId3");

    bytes32 rootHash = keccak256("rootHash");
    bytes32 rootHash2 = keccak256("rootHash2");
    bytes32 rootHash3 = keccak256("rootHash3");

    uint256 deadline = block.timestamp + 1 days;

    function setUp() public {
        registry = new Registry(relayer);
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        craftCoin = new CraftCoin(relayer, address(registry));
        gigMarketplace = new GigMarketplace(relayer, address(registry), address(paymentProcessor), address(craftCoin));

        vm.startPrank(relayer);
        registry.registerAsClientFor(client, "clientIpfs");
        token.claimFor(client);

        registry.registerAsClientFor(client2, "client2Ipfs");
        token.claimFor(client2);

        registry.registerAsArtisanFor(artisan, "artisanIpfs");
        craftCoin.mintFor(artisan);

        registry.registerAsArtisanFor(artisan2, "artisan2Ipfs");
        craftCoin.mintFor(artisan2);
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

    function testCreateGig() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        (address gigClient,,,,,,) = gigMarketplace.getGigInfo(databaseId);
        assertEq(gigClient, client);
    }

    function testCreateGigFor() public {
        vm.startPrank(relayer);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);
        vm.stopPrank();

        (address gigClient,,,,,,) = gigMarketplace.getGigInfo(databaseId);
        assertEq(gigClient, client);
    }

    function testNonRelayerCannotCreateGigFor() public {
        vm.prank(artisan);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );

        vm.expectRevert("Caller is not the relayer");
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);
    }

    function testNonClientCannotCreateGig() public {
        vm.prank(artisan);
        vm.expectRevert("Not a client");
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
    }

    function testCreateMultipleGigFor() public {
        vm.startPrank(relayer);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v, r, s);

        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 200 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash2, databaseId2, 200 * 10 ** 6, deadline, v2, r2, s2);
        vm.stopPrank();

        (address gigClient1,, uint256 payment1Id,,,,) = gigMarketplace.getGigInfo(databaseId);
        (address gigClient2,, uint256 payment2Id,,,,) = gigMarketplace.getGigInfo(databaseId2);
        assertEq(gigClient1, client);
        assertEq(payment1Id, 1);
        assertEq(gigClient2, client2);
        assertEq(payment2Id, 2);
    }

    function testUpdateGigInfo() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        gigMarketplace.updateGigInfo(databaseId, rootHash2);
        vm.stopPrank();

        (,,, bytes32 _rootHash,,,) = gigMarketplace.getGigInfo(databaseId);
        assertEq(_rootHash, rootHash2);
    }

    function testCannotUpdateGigInfoAsNotGigOwner() public {
        vm.startPrank(artisan);
        vm.expectRevert("Not gig owner");
        gigMarketplace.updateGigInfo(databaseId, rootHash2);
        vm.stopPrank();
    }

    // TODO: Client should not be able to update gig info (except for gig amount) after hiring an artisan
    // This will likely be handled in the backend

    function testCannotUpdateCompletedGig() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(relayer);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.prank(client);
        gigMarketplace.hireArtisan(databaseId, artisan);

        vm.prank(artisan);
        gigMarketplace.markComplete(databaseId);

        vm.startPrank(client);
        gigMarketplace.confirmComplete(databaseId);
        vm.expectRevert("Gig finished");
        gigMarketplace.updateGigInfo(databaseId, rootHash2);
        vm.stopPrank();
    }

    function testCannotUpdateClosedGig() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(relayer);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.startPrank(client);
        gigMarketplace.closeGig(databaseId);
        vm.expectRevert("Gig finished");
        gigMarketplace.updateGigInfo(databaseId, rootHash2);
        vm.stopPrank();
    }

    function testGetLatestRootHash() public {
        vm.startPrank(relayer);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(
            client, keccak256("rootHash1"), keccak256("databaseId1"), 100 * 10 ** 6, deadline, v, r, s
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 200 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(
            client2, keccak256("rootHash2"), keccak256("databaseId2"), 200 * 10 ** 6, deadline, v2, r2, s2
        );

        (uint8 v3, bytes32 r3, bytes32 s3) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 300 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(
            client, keccak256("rootHash3"), keccak256("databaseId3"), 300 * 10 ** 6, deadline, v3, r3, s3
        );

        (uint8 v4, bytes32 r4, bytes32 s4) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 400 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(
            client2, keccak256("rootHash4"), keccak256("databaseId4"), 400 * 10 ** 6, deadline, v4, r4, s4
        );
        vm.stopPrank();

        bytes32 latestRootHash = gigMarketplace.getLatestRootHash();
        assertEq(latestRootHash, keccak256("rootHash4"));
    }

    function testApplyForGig() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        address[] memory applicants = gigMarketplace.getGigApplicants(databaseId);
        assertEq(applicants[0], artisan);
    }

    function testCannotApplyForInvalidGigId() public {
        vm.startPrank(relayer);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        vm.expectRevert("Invalid gig ID");
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();
    }

    // TODO: Ensure to test that an unverified artisan cannot apply for a gig

    function testCannotApplyToClosedGig() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        gigMarketplace.closeGig(databaseId);
        vm.stopPrank();

        vm.startPrank(relayer);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        vm.expectRevert("Gig is closed");
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();
    }

    function testCannotApplyToGigWithHiredArtisan() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(relayer);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.prank(client);
        gigMarketplace.hireArtisan(databaseId, artisan);

        vm.startPrank(relayer);
        uint256 deadline2 = block.timestamp + 1 days;
        uint256 requiredCFT2 = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForArtisan(
            artisan2, address(gigMarketplace), requiredCFT2, deadline2, artisan2PrivateKey
        );
        vm.expectRevert("Artisan already hired");
        gigMarketplace.applyForGigFor(artisan2, databaseId, deadline, v2, r2, s2);
        vm.stopPrank();
    }

    function testCannotApplyForSameGigAgain() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(relayer);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        vm.expectRevert("Already applied");
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();
    }

    function testClientCannotApplyToTheirOwnGig() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        registry.registerAsArtisanFor(client, "clientArtisanIpfs");
        craftCoin.mintFor(client);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );

        vm.expectRevert("Cannot apply to your own gig");
        gigMarketplace.applyForGigFor(client, databaseId, deadline, v, r, s);
        vm.stopPrank();
    }

    function testHireArtisan() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        vm.stopPrank();

        (address gigClient, address hiredArtisan,,,,,) = gigMarketplace.getGigInfo(databaseId);
        assertEq(gigClient, client);
        assertEq(hiredArtisan, artisan);
    }

    function testCannotHireArtisanForInvalidGigId() public {
        vm.startPrank(relayer);
        vm.expectRevert("Invalid gig ID");
        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        vm.stopPrank();
    }

    function testNotGigOwnerCannotHireArtisan() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        vm.expectRevert("Not gig owner");
        gigMarketplace.hireArtisanFor(client2, databaseId, artisan);
        vm.stopPrank();
    }

    function testCannotHireAnotherArtisanAfterArtisanHasBeenHired() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(relayer);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.prank(client);
        gigMarketplace.hireArtisan(databaseId, artisan);
        vm.startPrank(relayer);
        uint256 deadline2 = block.timestamp + 1 days;
        uint256 requiredCFT2 = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForArtisan(
            artisan2, address(gigMarketplace), requiredCFT2, deadline2, artisan2PrivateKey
        );
        vm.expectRevert("Artisan already hired");
        gigMarketplace.applyForGigFor(artisan2, databaseId, deadline2, v2, r2, s2);
        vm.stopPrank();
    }

    function testCannotHireArtisanForClosedGig() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(relayer);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.prank(client);
        gigMarketplace.closeGig(databaseId);

        vm.expectRevert("Gig is closed");
        vm.prank(relayer);
        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
    }

    function testCannotHireArtisanThatDidNotApply() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.expectRevert("Not an applicant");
        vm.prank(relayer);
        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
    }

    function testMarkComplete() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        gigMarketplace.markCompleteFor(artisan, databaseId);
        vm.stopPrank();

        (,,,, bool artisanComplete,,) = gigMarketplace.getGigInfo(databaseId);
        assertTrue(artisanComplete);
    }

    function testCannotMarkCompleteForInvalidGigId() public {
        vm.startPrank(relayer);
        vm.expectRevert("Invalid gig ID");
        gigMarketplace.markCompleteFor(artisan, databaseId);
        vm.stopPrank();
    }

    function testCannotMarkCompleteAsNotHiredArtisan() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        vm.expectRevert("Not hired artisan");
        gigMarketplace.markCompleteFor(artisan, databaseId);
        vm.stopPrank();
    }

    function testCannotMarkCompletedGigAsComplete() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        gigMarketplace.markCompleteFor(artisan, databaseId);

        vm.expectRevert("Already marked");
        gigMarketplace.markCompleteFor(artisan, databaseId);
        vm.stopPrank();
    }

    function testConfirmComplete() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        gigMarketplace.markCompleteFor(artisan, databaseId);
        gigMarketplace.confirmCompleteFor(client, databaseId);
        vm.stopPrank();

        (,,,,, bool isComplete,) = gigMarketplace.getGigInfo(databaseId);
        assertTrue(isComplete);
    }

    function testCannotConfirmCompleteForInvalidGigId() public {
        vm.startPrank(relayer);
        vm.expectRevert("Invalid gig ID");
        gigMarketplace.confirmCompleteFor(client, databaseId);
        vm.stopPrank();
    }

    function testNotGigOwnerCannotConfirmComplete() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        gigMarketplace.markCompleteFor(artisan, databaseId);

        vm.expectRevert("Not gig owner");
        gigMarketplace.confirmCompleteFor(client2, databaseId);
        vm.stopPrank();
    }

    function testCannotConfirmCompleteWhenNotMarkedComplete() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        vm.expectRevert("Gig not completed || Closed");
        gigMarketplace.confirmCompleteFor(client, databaseId);
        vm.stopPrank();
    }

    function testCannotConfirmCompleteForAlreadyCompletedGig() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        gigMarketplace.markCompleteFor(artisan, databaseId);
        gigMarketplace.confirmCompleteFor(client, databaseId);

        vm.expectRevert("Gig not completed || Closed");
        gigMarketplace.confirmCompleteFor(client, databaseId);
        vm.stopPrank();
    }

    function testCannotConfirmClosedGigAsComplete() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(relayer);
        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        vm.prank(client);
        gigMarketplace.closeGig(databaseId);

        vm.expectRevert("Gig not completed || Closed");
        vm.prank(relayer);
        gigMarketplace.confirmCompleteFor(client, databaseId);
    }

    function testCloseGig() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        gigMarketplace.closeGig(databaseId);
        vm.stopPrank();

        (,,,,,, bool isClosed) = gigMarketplace.getGigInfo(databaseId);
        assertTrue(isClosed);

        uint256 clientBalance = token.balanceOf(client);
        assertEq(clientBalance, 100 * 10 ** 6 + 900 * 10 ** 6);
    }

    function testCannotCloseInvalidGigId() public {
        vm.startPrank(relayer);
        vm.expectRevert("Invalid gig ID");
        gigMarketplace.closeGig(databaseId);
        vm.stopPrank();
    }

    function testNotGigOwnerCannotCloseGig() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        vm.expectRevert("Not gig owner");
        gigMarketplace.closeGig(databaseId);
        vm.stopPrank();
    }

    function testCannotCloseActiveGig() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        vm.stopPrank();

        vm.prank(client);
        vm.expectRevert("Cannot close active gig");
        gigMarketplace.closeGig(databaseId);
    }

    function testCannotCloseCompletedGig() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        gigMarketplace.markCompleteFor(artisan, databaseId);
        vm.stopPrank();

        vm.expectRevert("Cannot close active gig");
        vm.prank(client);
        gigMarketplace.closeGig(databaseId);
    }

    function testCannotCloseGigThatIsAlreadyClosed() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        gigMarketplace.closeGig(databaseId);

        vm.expectRevert("Gig already Completed || Closed");
        gigMarketplace.closeGig(databaseId);
        vm.stopPrank();
    }

    function testGetClientGigReturnsCountZeroIfArtisanNotHired() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 200 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash2, databaseId2, 200 * 10 ** 6, deadline, v2, r2, s2);
        vm.stopPrank();

        uint256 clientGigCount = gigMarketplace.getClientGigCount(client);
        uint256 client2GigCount = gigMarketplace.getClientGigCount(client2);

        assertEq(clientGigCount, 0);
        assertEq(client2GigCount, 0);
    }

    function testGetClientGigReturnsCountOneIfArtisanHired() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        vm.stopPrank();

        uint256 clientGigCount = gigMarketplace.getClientGigCount(client);
        assertEq(clientGigCount, 1);
    }

    function testGetClientGigReturnsCountZeroIfGigClosed() public {
        vm.startPrank(client);
        token.approve(address(paymentProcessor), 100 * 10 ** 6);
        gigMarketplace.createGig(rootHash, databaseId, 100 * 10 ** 6);
        gigMarketplace.closeGig(databaseId);
        vm.stopPrank();

        uint256 clientGigCount = gigMarketplace.getClientGigCount(client);
        assertEq(clientGigCount, 0);
    }

    function testGetClientAndArtisanCount() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 200 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash2, databaseId2, 200 * 10 ** 6, deadline, v2, r2, s2);

        (uint8 v3, bytes32 r3, bytes32 s3) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 300 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash3, databaseId3, 300 * 10 ** 6, deadline, v3, r3, s3);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 vi, bytes32 ri, bytes32 si) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, vi, ri, si);

        uint256 requiredCFT2 = gigMarketplace.getRequiredCFT(databaseId2);
        (uint8 vii, bytes32 rii, bytes32 sii) = generatePermitSignatureForArtisan(
            artisan2, address(gigMarketplace), requiredCFT2, deadline, artisan2PrivateKey
        );
        gigMarketplace.applyForGigFor(artisan2, databaseId2, deadline, vii, rii, sii);

        uint256 requiredCFT3 = gigMarketplace.getRequiredCFT(databaseId3);
        (uint8 viii, bytes32 riii, bytes32 siii) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT3, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId3, deadline, viii, riii, siii);

        gigMarketplace.hireArtisanFor(client, databaseId, artisan);
        gigMarketplace.hireArtisanFor(client, databaseId2, artisan2);
        gigMarketplace.hireArtisanFor(client, databaseId3, artisan);
        vm.stopPrank();

        uint256 clientCount = gigMarketplace.getClientGigCount(client);
        assertEq(clientCount, 3);

        uint256 artisanCount = gigMarketplace.getArtisanHiredCount(artisan);
        uint256 artisan2Count = gigMarketplace.getArtisanHiredCount(artisan2);

        assertEq(artisanCount, 2);
        assertEq(artisan2Count, 1);
    }

    function testGetArtisanAppliedGig() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);
        vm.stopPrank();

        bytes32[] memory artisanAppliedGigs = gigMarketplace.getArtisanAppliedGigs(artisan);
        assertEq(artisanAppliedGigs.length, 1);
        assertEq(artisanAppliedGigs[0], databaseId);
    }

    function testGetArtisanAppliedMultipleGigs() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 200 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash2, databaseId2, 200 * 10 ** 6, deadline, v2, r2, s2);

        uint256 requiredCFT2 = gigMarketplace.getRequiredCFT(databaseId2);
        (uint8 v3, bytes32 r3, bytes32 s3) = generatePermitSignatureForArtisan(
            artisan2, address(gigMarketplace), requiredCFT2, deadline, artisan2PrivateKey
        );
        gigMarketplace.applyForGigFor(artisan2, databaseId2, deadline, v3, r3, s3);
        vm.stopPrank();

        bytes32[] memory artisanAppliedGigs = gigMarketplace.getArtisanAppliedGigs(artisan);
        assertEq(artisanAppliedGigs.length, 1);
        assertEq(artisanAppliedGigs[0], databaseId);

        bytes32[] memory artisan2AppliedGigs = gigMarketplace.getArtisanAppliedGigs(artisan2);
        assertEq(artisan2AppliedGigs.length, 1);
        assertEq(artisan2AppliedGigs[0], databaseId2);
    }

    function testGetAllGigsAppliedByOneArtisan() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        uint256 requiredCFT = gigMarketplace.getRequiredCFT(databaseId);
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId, deadline, v, r, s);

        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 200 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash2, databaseId2, 200 * 10 ** 6, deadline, v2, r2, s2);

        uint256 requiredCFT2 = gigMarketplace.getRequiredCFT(databaseId2);
        (uint8 v3, bytes32 r3, bytes32 s3) = generatePermitSignatureForArtisan(
            artisan, address(gigMarketplace), requiredCFT2, deadline, artisanPrivateKey
        );
        gigMarketplace.applyForGigFor(artisan, databaseId2, deadline, v3, r3, s3);

        vm.stopPrank();
        bytes32[] memory artisanAppliedGigs = gigMarketplace.getArtisanAppliedGigs(artisan);
        assertEq(artisanAppliedGigs.length, 2);
        assertEq(artisanAppliedGigs[0], databaseId);
        assertEq(artisanAppliedGigs[1], databaseId2);
    }

    function testGetClientCreatedGigs() public {
        vm.startPrank(relayer);
        (uint8 v_, bytes32 r_, bytes32 s_) = generatePermitSignatureForClient(
            client, address(paymentProcessor), 100 * 10 ** 6, deadline, clientPrivateKey
        );
        gigMarketplace.createGigFor(client, rootHash, databaseId, 100 * 10 ** 6, deadline, v_, r_, s_);

        (uint8 v2, bytes32 r2, bytes32 s2) = generatePermitSignatureForClient(
            client2, address(paymentProcessor), 200 * 10 ** 6, deadline, client2PrivateKey
        );
        gigMarketplace.createGigFor(client2, rootHash2, databaseId2, 200 * 10 ** 6, deadline, v2, r2, s2);
        vm.stopPrank();

        bytes32[] memory clientGigs = gigMarketplace.getClientCreatedGigs(client);
        assertEq(clientGigs.length, 1);
        assertEq(clientGigs[0], databaseId);

        bytes32[] memory client2Gigs = gigMarketplace.getClientCreatedGigs(client2);
        assertEq(client2Gigs.length, 1);
        assertEq(client2Gigs[0], databaseId2);
    }
}
