// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Registry {
    enum UserType {
        None,
        Artisan,
        Client
    }

    struct Artisan {
        string ipfsHash;
        bool isVerified;
        uint256 registrationDate;
    }

    struct Client {
        string ipfsHash;
        uint256 registrationDate;
    }

    mapping(address => Artisan) public artisans;
    mapping(address => Client) public clients;
    mapping(address => UserType) public userTypes;

    address[] public artisanAddresses;
    address[] public clientAddresses;

    event ArtisanRegistered(address indexed artisanAddress, string ipfsHash);
    event ClientRegistered(address indexed clientAddress, string ipfsHash);
    event ArtisanVerified(address indexed artisanAddress);

    function registerAsArtisan(string memory _ipfsHash) external {
        require(userTypes[msg.sender] == UserType.None, "User already registered");

        artisans[msg.sender] = Artisan({ipfsHash: _ipfsHash, isVerified: false, registrationDate: block.timestamp});

        userTypes[msg.sender] = UserType.Artisan;
        artisanAddresses.push(msg.sender);
        verifyArtisan(msg.sender);  // Just for now to verify later
        emit ArtisanRegistered(msg.sender, _ipfsHash);
    }

    function registerAsClient(string memory _ipfsHash) external {
        require(userTypes[msg.sender] == UserType.None, "User already registered");

        clients[msg.sender] = Client({ipfsHash: _ipfsHash, registrationDate: block.timestamp});

        userTypes[msg.sender] = UserType.Client;
        clientAddresses.push(msg.sender);
        emit ClientRegistered(msg.sender, _ipfsHash);
    }

    function verifyArtisan(address _artisanAddress) internal {
        // Only Owner or a DAO system will be set-up in future implemetations
        require(userTypes[_artisanAddress] == UserType.Artisan, "Not registered as an artisan");
        require(artisans[_artisanAddress].registrationDate != 0, "Artisan not registered");
        require(!artisans[_artisanAddress].isVerified, "Artisan already verified");

        artisans[_artisanAddress].isVerified = true;
        emit ArtisanVerified(_artisanAddress);
    }

    function isArtisanVerified(address _artisanAddress) external view returns (bool) {
        require(userTypes[_artisanAddress] == UserType.Artisan, "Not registered as an artisan");
        return artisans[_artisanAddress].isVerified;
    }

    function isClient(address _clientAddress) external view returns (bool) {
        return (userTypes[_clientAddress] == UserType.Client);
    }

    function isArtisan(address _artisanAddress) external view returns (bool) {
        return (userTypes[_artisanAddress] == UserType.Artisan);
    }

    function getArtisanDetails(address _artisanAddress)
        external
        view
        returns (string memory ipfsHash, bool isVerified, uint256 registrationDate)
    {
        require(userTypes[_artisanAddress] == UserType.Artisan, "Not registered as an artisan");
        Artisan storage artisan = artisans[_artisanAddress];
        return (artisan.ipfsHash, artisan.isVerified, artisan.registrationDate);
    }

    function getClientDetails(address _clientAddress)
        external
        view
        returns (string memory ipfsHash, uint256 registrationDate)
    {
        require(userTypes[_clientAddress] == UserType.Client, "Not registered as a client");
        Client storage client = clients[_clientAddress];
        return (client.ipfsHash, client.registrationDate);
    }

    function getArtisanCount() external view returns (uint256) {
        return artisanAddresses.length;
    }

    function getClientCount() external view returns (uint256) {
        return clientAddresses.length;
    }
}