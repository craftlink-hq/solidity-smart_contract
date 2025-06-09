// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IChatSystem {
    event ConversationStarted(bytes32 indexed conversationId, bytes32 rootHash);
    event ConversationUpdated(bytes32 indexed conversationId, bytes32 newRootHash);

    function startConversation(bytes32 _conversationId, bytes32 _databaseId, bytes32 _initialRootHash) external;
    function updateConversation(bytes32 _conversationId, bytes32 _databaseId, bytes32 _newRootHash) external;
    function getConversationDetails(bytes32 _conversationId) external view returns (bytes32 rootHash, bool isActive);
}
