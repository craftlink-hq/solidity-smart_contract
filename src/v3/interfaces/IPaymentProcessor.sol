// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPaymentProcessor {
    event PaymentCreated(uint256 indexed paymentId, address indexed client, uint256 amount);
    event PaymentReleased(uint256 indexed paymentId, uint256 amountToArtisan, uint256 platformFee);
    event PaymentRefunded(uint256 indexed paymentId, uint256 amountToClient);
    event PlatformFeeUpdated(uint256 newFeePercentage);

    function createPaymentFor(address _client, uint256 _amount) external;
    function currentPaymentId() external view returns (uint256);
    function releaseArtisanFundsFor(address artisan, uint256 _paymentId) external;
    function refundClientFunds(uint256 _paymentId) external;
    function updatePlatformFee(uint256 _newFeePercentage) external;
    function getPaymentDetails(uint256 _paymentId)
        external
        view
        returns (address client, uint256 amount, uint256 platformFee, bool isReleased);
    function getClientAmountSpent(address _client) external view returns (uint256);
    function getArtisanAmountMade(address _artisan) external view returns (uint256);
    function hasClientReleasedFunds(uint256 _paymentId) external view returns (bool);
    function getPlatformFeePercentage() external view returns (uint256);
}
