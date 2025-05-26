// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GigMarketplace.sol";

contract ChatSystem {
    struct ChatInfo {
        bytes32 rootHash;
        bool isActive;
    }

    GigMarketplace public gigMarketplace;
    mapping(bytes32 => ChatInfo) public conversations;

    event ConversationStarted(bytes32 indexed conversationId, bytes32 rootHash);
    event ConversationUpdated(bytes32 indexed conversationId, bytes32 newRootHash);

    constructor(address _gigMarketplace) {
        gigMarketplace = GigMarketplace(_gigMarketplace);
    }

    function startConversation(bytes32 _conversationId, bytes32 _databaseId, bytes32 _initialRootHash) external {
        (address client, address hiredArtisan, , , , , ) = gigMarketplace.getGigInfo(_databaseId);
        require(msg.sender == client || msg.sender == hiredArtisan, "Not authorized");
        require(!conversations[_conversationId].isActive, "Already exists");

        conversations[_conversationId] = ChatInfo({
            rootHash: _initialRootHash,
            isActive: true
        });

        emit ConversationStarted(_conversationId, _initialRootHash);
    }

    function updateConversation(bytes32 _conversationId, bytes32 _databaseId, bytes32 _newRootHash) external {
        ChatInfo storage chat = conversations[_conversationId];
        require(chat.isActive, "Chat not active");
    
        (address client, address hiredArtisan, , , , , ) = gigMarketplace.getGigInfo(_databaseId);
        require(msg.sender == client || msg.sender == hiredArtisan, "Not authorized");
    
        chat.rootHash = _newRootHash;
        emit ConversationUpdated(_conversationId, _newRootHash);
    }

    function getConversationDetails(bytes32 _conversationId) 
        external 
        view 
        returns (bytes32 rootHash, bool isActive) 
    {
        ChatInfo memory chat = conversations[_conversationId];
        return (chat.rootHash, chat.isActive);
    }
}