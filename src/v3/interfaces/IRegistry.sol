// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRegistry {
    event ArtisanRegistered(address indexed artisanAddress, string ipfsHash);
    event ClientRegistered(address indexed clientAddress, string ipfsHash);
    event ArtisanVerified(address indexed artisanAddress);

    function registerAsArtisanFor(address _user, string memory _ipfsHash) external;
    function registerAsClientFor(address _user, string memory _ipfsHash) external;
    function isArtisanVerified(address _artisanAddress) external view returns (bool);
    function isClient(address _clientAddress) external view returns (bool);
    function isArtisan(address _artisanAddress) external view returns (bool);
    function getArtisanDetails(address _artisanAddress)
        external
        view
        returns (string memory ipfsHash, bool isVerified, uint256 registrationDate);
    function getClientDetails(address _clientAddress)
        external
        view
        returns (string memory ipfsHash, uint256 registrationDate);
    function getArtisanCount() external view returns (uint256);
    function getClientCount() external view returns (uint256);
    function getAllArtisans() external view returns (address[] memory);
    function getAllClients() external view returns (address[] memory);
}
