// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Token.sol";

contract PaymentProcessor {
    Token public token;
    uint256 public platformFeePercentage;
    address public platformWallet; // deployer for now

    struct Payment {
        address client;
        uint256 amount;
        uint256 platformFee;
        bool isReleased;
    }

    mapping(uint256 => Payment) public payments;
    mapping(address => uint256) internal amountSpent;
    mapping(address => uint256) internal amountMade;
    uint256 public paymentId;

    event PaymentCreated(uint256 indexed paymentId, address indexed client, uint256 amount);
    event PaymentReleased(uint256 indexed paymentId, uint256 amountToArtisan, uint256 platformFee);
    event PaymentRefunded(uint256 indexed paymentId, uint256 amountToClient);
    event PlatformFeeUpdated(uint256 newFeePercentage);

    constructor(address _tokenAddress) {
        token = Token(_tokenAddress);
        platformFeePercentage = 5; // 5%
        platformWallet = msg.sender;
    }

    function createPayment(address _client, uint256 _amount) external {
        require(_amount > 1000000, "Amount must be greater than 1 USDT");
        require(token.balanceOf(_client) >= _amount, "Insufficient token balance");

        uint256 platformFee = (_amount * platformFeePercentage) / 100;

        token.transferFrom(_client, address(this), _amount);
        paymentId++;

        payments[paymentId] = Payment({
            client: _client,
            amount: _amount,
            platformFee: platformFee,
            isReleased: false
        });

        emit PaymentCreated(paymentId, _client, _amount);
    }

    function currentPaymentId() external view returns (uint256) {
        return paymentId;
    }

    function releaseArtisanFunds(address _artisan, uint256 _paymentId) external {
        Payment storage payment = payments[_paymentId];
        require(!payment.isReleased, "Payment already released");

        payment.isReleased = true;
        uint256 amountToArtisan = payment.amount - payment.platformFee;

        token.transfer(_artisan, amountToArtisan);
        token.transfer(platformWallet, payment.platformFee);

        amountSpent[payment.client] = amountSpent[payment.client] + payment.amount;
        amountMade[_artisan] = amountMade[_artisan] + payment.amount;

        emit PaymentReleased(_paymentId, amountToArtisan, payment.platformFee);
    }

    function refundClientFunds(uint256 _paymentId) external {
        Payment storage payment = payments[_paymentId];
        require(!payment.isReleased, "Payment already released");

        payment.isReleased = true;
        token.transfer(payment.client, payment.amount);

        emit PaymentRefunded(_paymentId, payment.amount);
    }

    function updatePlatformFee(uint256 _newFeePercentage) external  {
        require(msg.sender == platformWallet, "Only the platform wallet can update the fee");
        require(_newFeePercentage <= 20, "Fee percentage must be between 0 and 20");

        platformFeePercentage = _newFeePercentage;
        emit PlatformFeeUpdated(_newFeePercentage);
    }

    function getPaymentDetails(uint256 _paymentId) external view returns (
        address client,
        uint256 amount,
        uint256 platformFee,
        bool isReleased
    ) {
        Payment storage payment = payments[_paymentId];
        return (
            payment.client,
            payment.amount,
            payment.platformFee,
            payment.isReleased
        );
    }

    function getClientAmountSpent(address _client) external view returns (uint256) {
        return amountSpent[_client];
    }

    function getArtisanAmountMade(address _artisan) external view returns (uint256) {
        return amountMade[_artisan];
    }
}