// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v2/PaymentProcessor.sol";
import "../../src/v2/Token.sol";

contract PaymentProcessorTest is Test {
    Token token;
    PaymentProcessor paymentProcessor;
    address relayer = address(0x1);
    address client = address(0x2);
    address artisan = address(0x3);

    function setUp() public {
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));

        vm.startPrank(client);
        token.claim(); // 1000 USDT
        token.approve(address(paymentProcessor), 1000 * 10 ** 6);
        vm.stopPrank();
    }

    function testCreatePayment() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        (address paymentClient, uint256 amount,,) = paymentProcessor.getPaymentDetails(1);
        assertEq(paymentClient, client);
        assertEq(amount, 100 * 10 ** 6);
    }

    function testCannotCreatePaymentWithLessThanMinimum() public {
        vm.expectRevert("Amount must be greater than 10 USDT");
        vm.prank(client);
        paymentProcessor.createPayment(client, 9 * 10 ** 6);
    }

    function testCannotCreatePaymentWithInsufficientBalance() public {
        vm.expectRevert("Insufficient token balance");
        vm.prank(client);
        paymentProcessor.createPayment(client, 2000 * 10 ** 6);
    }

    function testReleaseArtisanFunds() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(artisan);
        paymentProcessor.releaseArtisanFunds(artisan, 1);
        assertEq(token.balanceOf(artisan), 95 * 10 ** 6); // 5% fee
    }

    function testReleaseClientFunds() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(client);
        paymentProcessor.refundClientFunds(1);
        assertEq(token.balanceOf(client), 1000 * 10 ** 6);
    }

    function testCannotReleaseClientFundsMoreThanOnce() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(artisan);
        paymentProcessor.releaseArtisanFunds(artisan, 1);
        vm.expectRevert("Payment already released");
        vm.prank(client);
        paymentProcessor.refundClientFunds(1);
    }

    // TODO: Add test for updatePlatform Fee

    function testCurrentPaymentId() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        uint256 currentId = paymentProcessor.currentPaymentId();
        assertEq(currentId, 1);
    }

    function testInsufficientBalance() public {
        vm.expectRevert("Insufficient token balance");
        vm.prank(client);
        paymentProcessor.createPayment(client, 2000 * 10 ** 6); // More than 1000 USDT balance
    }

    function testAmountLessThanMinimum() public {
        vm.expectRevert("Amount must be greater than 10 USDT");
        vm.prank(client);
        paymentProcessor.createPayment(client, 5 * 10 ** 6);
    }

    function testPaymentAlreadyReleased() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(artisan);
        paymentProcessor.releaseArtisanFunds(artisan, 1);
        vm.expectRevert("Payment already released");
        vm.prank(artisan);
        paymentProcessor.releaseArtisanFunds(artisan, 1);
    }

    function testReleaseArtisanFundsFor() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(relayer);
        paymentProcessor.releaseArtisanFundsFor(artisan, 1);
        assertEq(token.balanceOf(artisan), 95 * 10 ** 6); // 5% fee
    }

    function testReleaseFivePayments() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(client);
            paymentProcessor.createPayment(client, 100 * 10 ** 6);
            vm.prank(artisan);
            paymentProcessor.releaseArtisanFunds(artisan, i + 1);
        }
        assertEq(token.balanceOf(artisan), 475 * 10 ** 6); // 5 payments of 95 USDT each
    }

    function testReleaseOnlyThe5thPayment() public {
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(client);
            paymentProcessor.createPayment(client, 100 * 10 ** 6);
        }
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(artisan);
        paymentProcessor.releaseArtisanFunds(artisan, 5); // Only release the 5th payment
        assertEq(token.balanceOf(artisan), 95 * 10 ** 6);
    }

    function testAmountSpentAndMade() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(artisan);
        paymentProcessor.releaseArtisanFunds(artisan, 1);
        assertEq(paymentProcessor.getClientAmountSpent(client), 100 * 10 ** 6);
        assertEq(paymentProcessor.getArtisanAmountMade(artisan), 95 * 10 ** 6 + 5 * 10 ** 6); // platform fee isn't deducted from artisan's earnings
    }

    function testGetPaymentDetails() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        (address paymentClient, uint256 amount, uint256 platformFee, bool isReleased) =
            paymentProcessor.getPaymentDetails(1);
        assertEq(paymentClient, client);
        assertEq(amount, 100 * 10 ** 6);
        assertEq(platformFee, 5 * 10 ** 6); // 5% of 100 USDT
        assertFalse(isReleased);
    }

    function testRefundPayment() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(client);
        paymentProcessor.refundClientFunds(1);
        assertEq(token.balanceOf(client), 1000 * 10 ** 6); // refunded full amount
        (,,, bool isReleased) = paymentProcessor.getPaymentDetails(1);
        assertTrue(isReleased);
    }

    function testRefundPaymentAlreadyReleased() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(artisan);
        paymentProcessor.releaseArtisanFunds(artisan, 1);
        vm.expectRevert("Payment already released");
        vm.prank(client);
        paymentProcessor.refundClientFunds(1);
    }
}
