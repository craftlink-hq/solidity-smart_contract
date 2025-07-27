// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Registry {
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
    mapping(address => bool) public isRegisteredAsArtisan;
    mapping(address => bool) public isRegisteredAsClient;

    address[] public artisanAddresses;
    address[] public clientAddresses;
    address public immutable relayer;

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Caller is not the relayer");
        _;
    }

    event ArtisanRegistered(address indexed artisanAddress, string ipfsHash);
    event ClientRegistered(address indexed clientAddress, string ipfsHash);
    event ArtisanVerified(address indexed artisanAddress);

    constructor(address _relayer) {
        relayer = _relayer;
    }

    function registerAsArtisanFor(address _user, string memory _ipfsHash) external onlyRelayer {
        require(!isRegisteredAsArtisan[_user], "User already registered as an artisan");

        artisans[_user] = Artisan({ipfsHash: _ipfsHash, isVerified: false, registrationDate: block.timestamp});
        isRegisteredAsArtisan[_user] = true;

        artisanAddresses.push(_user);
        verifyArtisan(_user);

        emit ArtisanRegistered(_user, _ipfsHash);
    }

    function registerAsClientFor(address _user, string memory _ipfsHash) external onlyRelayer {
        require(!isRegisteredAsClient[_user], "User already registered as a client");
        clients[_user] = Client({ipfsHash: _ipfsHash, registrationDate: block.timestamp});

        isRegisteredAsClient[_user] = true;
        clientAddresses.push(_user);

        emit ClientRegistered(_user, _ipfsHash);
    }

    function verifyArtisan(address _artisanAddress) internal {
        // Only Owner or a DAO system will be set-up in future implemetations
        require(isRegisteredAsArtisan[_artisanAddress], "Not registered as an artisan");
        require(artisans[_artisanAddress].registrationDate != 0, "Artisan not registered");
        require(!artisans[_artisanAddress].isVerified, "Artisan already verified");

        artisans[_artisanAddress].isVerified = true;
        emit ArtisanVerified(_artisanAddress);
    }

    function isArtisanVerified(address _artisanAddress) external view returns (bool) {
        require(isRegisteredAsArtisan[_artisanAddress], "Not registered as an artisan");
        return artisans[_artisanAddress].isVerified;
    }

    function isClient(address _clientAddress) external view returns (bool) {
        return isRegisteredAsClient[_clientAddress];
    }

    function isArtisan(address _artisanAddress) external view returns (bool) {
        return isRegisteredAsArtisan[_artisanAddress];
    }

    function getArtisanDetails(address _artisanAddress)
        external
        view
        returns (string memory ipfsHash, bool isVerified, uint256 registrationDate)
    {
        require(isRegisteredAsArtisan[_artisanAddress], "Not registered as an artisan");
        Artisan storage artisan = artisans[_artisanAddress];
        return (artisan.ipfsHash, artisan.isVerified, artisan.registrationDate);
    }

    function getClientDetails(address _clientAddress)
        external
        view
        returns (string memory ipfsHash, uint256 registrationDate)
    {
        require(isRegisteredAsClient[_clientAddress], "Not registered as a client");
        Client storage client = clients[_clientAddress];
        return (client.ipfsHash, client.registrationDate);
    }

    function getArtisanCount() external view returns (uint256) {
        return artisanAddresses.length;
    }

    function getClientCount() external view returns (uint256) {
        return clientAddresses.length;
    }

    function getAllArtisans() external view returns (address[] memory) {
        return artisanAddresses;
    }

    function getAllClients() external view returns (address[] memory) {
        return clientAddresses;
    }
}
