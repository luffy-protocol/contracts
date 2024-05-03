// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interface/hyperlane/IMailbox.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

error InadequateCrosschainFee(uint32 destinationDomain, uint256 requiredFee, uint256 sentFee);
error NotMailbox(address caller);

// Deployed on Ethereum Sepolia
contract ZkCricketOracle is FunctionsClient, ConfirmedOwner {
    // Library Imports
    using Strings for uint256;
    using FunctionsRequest for FunctionsRequest.Request;  

    mapping(uint256=>string) public gameResults;
    mapping(uint256=>bytes32) public pointsMerkleRoot;

    // Oracle Variables
    uint256 public gameId;
    mapping(uint256=>string) public playerIdRemappings;

    // Hyperlane Variables
    IMailbox public mailbox;
    bytes32 public protocolAddress;
    uint32 public destinationDomain;

    // Chainlink Variables
    bytes32 public donId;
    address public functionsRouter;
    address public upkeepContract;
    string public sourceCode;
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    uint32 public s_callbackGasLimit=300000;
    uint64 public s_subscriptionId;
    mapping(bytes32=>uint256) public requestToGameId;

    constructor(address _functionsRouter, uint32 _destinationDomain, bytes32 _protocolAddress, IMailbox _mailbox, string memory _sourceCode, uint64 _subscriptionId, bytes32 _donId) 
    FunctionsClient(_functionsRouter) ConfirmedOwner(msg.sender) 
    {
        // Hyperlane Initializations
        mailbox = _mailbox;
        protocolAddress=_protocolAddress;
        destinationDomain=_destinationDomain;

        // Chainlink Initializations
        functionsRouter=_functionsRouter;
        sourceCode=_sourceCode;
        s_subscriptionId=_subscriptionId;
        donId=_donId;
    }

    event ResultsFetchInitiated(uint256 gameweek, bytes32 requestId);
    event ResultsPublished(bytes32 indexed requestId, bytes32 pointsMerkleRoot, string gameResults);
    event ResultsFetchFailed(uint256 gameweek, bytes32 requestId, bytes error);
    event ResultsDispatched(uint256 gameweek, bytes32 messageId, uint256 fee);

    modifier onlyMailbox() {
        if(msg.sender != address(mailbox)) revert NotMailbox(msg.sender);
        _;
    }

    function setProtocolAddress(bytes32 _protocolAddress) public onlyOwner {
        protocolAddress=_protocolAddress;
    }

    function setPlayerIdRemmapings(uint256 _gameId, string memory _remapping) public onlyOwner {
        playerIdRemappings[_gameId] = _remapping;
        gameId=_gameId;
    }

    // Chainlink Functions
    function triggerFetchGameResults(uint8 donHostedSecretsSlotID, uint64 donHostedSecretsVersion) external onlyOwner{
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        req.addDONHostedSecrets(
            donHostedSecretsSlotID,
            donHostedSecretsVersion
        );
        string[] memory args= new string[](2);
        args[0]=Strings.toString(gameId);
        args[1]=playerIdRemappings[gameId];
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            s_callbackGasLimit,
            donId
        );
        requestToGameId[s_lastRequestId] = gameId;
        emit ResultsFetchInitiated(gameId, s_lastRequestId);
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        s_lastResponse = response;
        s_lastError = err;
        if(s_lastResponse.length == 0) {
            emit ResultsFetchFailed(requestToGameId[requestId], requestId, err);
        }else{
            (bytes32 _pointsMerkleRoot, string memory _gameResults) = abi.decode(s_lastResponse, (bytes32, string));
            pointsMerkleRoot[requestToGameId[requestId]] = _pointsMerkleRoot;
            gameResults[requestToGameId[requestId]] = _gameResults;
            emit ResultsPublished(requestId, _pointsMerkleRoot, _gameResults);
        }
    } 

    function triggerResultsCrosschain(uint256 _gameId) public payable onlyOwner {
        bytes memory _data= abi.encode(_gameId, pointsMerkleRoot[_gameId], gameResults[_gameId]);
        uint256 _requiredFee = mailbox.quoteDispatch(destinationDomain, protocolAddress, _data);
        if(msg.value < _requiredFee) revert InadequateCrosschainFee(destinationDomain, _requiredFee, msg.value);
        bytes32 messageId = mailbox.dispatch{value: msg.value}(destinationDomain, protocolAddress, _data);
        emit ResultsDispatched(_gameId, messageId, _requiredFee);
    }

    // Testing functions

    function updateSourceCode(string memory _sourceCode) public onlyOwner {
        sourceCode=_sourceCode;
    }

    function updateProtocolAddress(bytes32 _protocolAddress) public onlyOwner {
        protocolAddress=_protocolAddress;
    }

    function setPointsMerkleRoot(uint256 _gameId, bytes32 _pointsMerkleRoot) public onlyOwner {
        pointsMerkleRoot[_gameId] = _pointsMerkleRoot;
    }

    function setGameResults(uint256 _gameId, string memory _gameResults) public onlyOwner {
        gameResults[_gameId] = _gameResults;
    }
    
}