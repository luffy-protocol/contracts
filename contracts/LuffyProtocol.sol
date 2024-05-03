// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {UltraVerifier} from "./zk/plonk_vk.sol";

error NotOwner(address caller);
error NotMailbox(address caller);
error InvalidGameweek(uint256 gameId);
error SelectSquadDisabled(uint256 gameId);
error ZeroKnowledgeVerificationFailed();
error NotAllowedCaller(address caller, address owner);
error UnexpectedRequestID(bytes32 requestId);
error ResultsNotPublished(uint256 gameId);


contract LuffyProtocol is FunctionsClient, ConfirmedOwner {
    // Library Imports
    using Strings for uint256;
    using FunctionsRequest for FunctionsRequest.Request;  

    // LuffyProtocol Variables
    mapping(uint256=>mapping(address=>bytes32)) public gameToSquadHash;
    mapping(uint256=>mapping(address=>uint256)) public gamePoints;
    mapping(uint256=>string) public gameResults;
    mapping(uint256=>bytes32) public pointsMerkleRoot;
    mapping(uint256=>string) public playerIdRemappings;
    mapping(uint256=>bool) public isSelectSquadEnabled;
    string[] public playersMetadata;

    // zk Variables
    UltraVerifier public zkVerifier; 
    bool public isZkVerificationEnabled;

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
    

    constructor(address _functionsRouter, string memory _sourceCode, uint64 _subscriptionId, bytes32 _donId) FunctionsClient(_functionsRouter) ConfirmedOwner(msg.sender) 
    {
        // LuffyProtocol Initializations
        isZkVerificationEnabled = true;

        // Chainlink Initializations
        functionsRouter=_functionsRouter;
        sourceCode=_sourceCode;
        s_subscriptionId=_subscriptionId;
        donId=_donId;

        // zk Initializations
        zkVerifier=new UltraVerifier();

    }

    event GamePlayerIdRemappingSet(uint256 gameId, string remapping);
    event PlayersMetadataUpdated(uint256 playersMetadataLength, string[] playersMetadata);
    event SquadRegistered(uint256 gameId, bytes32 squadHash, address registrant);
    event PointsClaimed(uint256 gameId, address claimer, uint256 totalPoints);
    event ResultsFetchInitiated(uint256 gameId, bytes32 requestId);
    event ResultsPublished(uint256 gameId, bytes32 pointsMerkleRoot, string gameResults);
    event ResultsFetchFailed(uint256 gameId, bytes32 requestId, bytes error);
    event ClaimPointsDisabled(uint256 gameId);


    function setPlayerIdRemmapings(uint256 _gameId, string memory _remapping) public onlyOwner {
        playerIdRemappings[_gameId] = _remapping;
        isSelectSquadEnabled[_gameId] = true;
        emit GamePlayerIdRemappingSet(_gameId, _remapping);
    }

    function registerPlayers(string[] memory _playersMetadata) public onlyOwner {
        for(uint256 i=0; i<_playersMetadata.length; i++) playersMetadata.push(_playersMetadata[i]);
        emit PlayersMetadataUpdated(playersMetadata.length, _playersMetadata);
    }

    function registerSquad(uint256 _gameId, bytes32 _squadHash) public {
        if(!isSelectSquadEnabled[_gameId]) revert SelectSquadDisabled(_gameId);

        gameToSquadHash[_gameId][msg.sender] = _squadHash;
        emit SquadRegistered(_gameId, _squadHash, msg.sender);
    }

    function claimPoints(uint256 _gameId, uint256 totalPoints, bytes calldata _proof) public {
        // Enable in Production
        // if(isSelectSquadEnabled[_gameId]) revert SelectSquadDisabled(_gameId);
        if(pointsMerkleRoot[_gameId] == bytes32(0)) revert ResultsNotPublished(_gameId);

        if(isZkVerificationEnabled){
            bytes32[] memory _publicInputs=new bytes32[](2);
            _publicInputs[0]=pointsMerkleRoot[_gameId];
            _publicInputs[1]=gameToSquadHash[_gameId][msg.sender];
            _publicInputs[2]= bytes32(totalPoints);
            try zkVerifier.verify(_proof, _publicInputs)
            {
               gamePoints[_gameId][msg.sender] = totalPoints;
                emit PointsClaimed(_gameId, msg.sender, totalPoints);
            }catch{
                revert ZeroKnowledgeVerificationFailed();
            }
        } else{
            gamePoints[_gameId][msg.sender] = totalPoints;
            emit PointsClaimed(_gameId, msg.sender, totalPoints);
        }
    }

    // Chainlink Functions
    function triggerFetchGameResults(uint256 _gameId, uint8 donHostedSecretsSlotID, uint64 donHostedSecretsVersion) external onlyOwner{
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        req.addDONHostedSecrets(
            donHostedSecretsSlotID,
            donHostedSecretsVersion
        );
        string[] memory args= new string[](2);
        args[0]=Strings.toString(_gameId);
        args[1]=playerIdRemappings[_gameId];
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            s_callbackGasLimit,
            donId
        );
        requestToGameId[s_lastRequestId] = _gameId;
        emit ResultsFetchInitiated(_gameId, s_lastRequestId);
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        s_lastResponse = response;
        s_lastError = err;
        if(s_lastResponse.length == 0) {
            emit ResultsFetchFailed(requestToGameId[requestId], requestId, err);
        }else{
            uint256 _gameId = requestToGameId[requestId];
            (bytes32 _pointsMerkleRoot, string memory _gameResults) = abi.decode(s_lastResponse, (bytes32, string));
            pointsMerkleRoot[_gameId] = _pointsMerkleRoot;
            gameResults[_gameId] = _gameResults;
            emit ResultsPublished(_gameId, _pointsMerkleRoot, _gameResults);
        }
    } 

    // Testing helpers
    function setSelectSquadEnabled(uint256 _gameId, bool _isSelectSquadEnabled) public onlyOwner {
        isSelectSquadEnabled[_gameId] = _isSelectSquadEnabled;
    }

    function updateSourceCode(string memory _sourceCode) public onlyOwner {
        sourceCode=_sourceCode;
    }

    function setPointsMerkleRoot(uint256 _gameweek, bytes32 _pointsMerkleRoot) public onlyOwner {
        pointsMerkleRoot[_gameweek] = _pointsMerkleRoot;
    }

    function setZkVerificationEnabled(bool _isZkVerificationEnabled) public onlyOwner {
        isZkVerificationEnabled = _isZkVerificationEnabled;
    }

    function setGameResults(uint256 _gameId, string memory _gameResults) public onlyOwner {
        gameResults[_gameId] = _gameResults;
    }
    
}