// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/v2/PaymentProcessor.sol";
import "../src/v2/Token.sol";

contract PaymentProcessorTest is Test {
    Token token;
    PaymentProcessor paymentProcessor;
    address relayer = address(0x1);
    address client = address(0x2);
    address artisan = address(0x3);

    function setUp() public {
        token = new Token(relayer);
        paymentProcessor = new PaymentProcessor(relayer, address(token));
        vm.prank(client);
        token.claim(); // 1000 USDT
        vm.prank(client);
        token.approve(address(paymentProcessor), 1000 * 10 ** 6);
    }

    function testCreatePayment() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        (address paymentClient, uint256 amount,,) = paymentProcessor.getPaymentDetails(1);
        assertEq(paymentClient, client);
        assertEq(amount, 100 * 10 ** 6);
    }

    function testReleaseFunds() public {
        vm.prank(client);
        paymentProcessor.createPayment(client, 100 * 10 ** 6);
        vm.prank(artisan);
        paymentProcessor.releaseArtisanFunds(artisan, 1);
        assertEq(token.balanceOf(artisan), 95 * 10 ** 6); // 5% fee
    }
}
