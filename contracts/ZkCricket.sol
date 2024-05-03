// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interface/hyperlane/IMailbox.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {UltraVerifier} from "./zk/plonk_vk.sol";

error NotOwner(address caller);
error NotMailbox(address caller);
error InvalidGameweek(uint256 gameweek);
error SelectSquadDisabled(uint256 gameweek);
error InadequateCrosschainFee(uint32 destinationDomain, uint256 requiredFee, uint256 sentFee);
error ZeroKnowledgeVerificationFailed();
error NotAllowedCaller(address caller, address owner);
error NotAllowedCrosschainCaller(bytes32 caller);
error UnexpectedRequestID(bytes32 requestId);
error ResultsNotPublished(uint256 gameweek);

contract LuffyProtocol {
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
    uint256 public gameCounter;
    string[] public playersMetadata;
    address public owner;

    // Hyperlane Variables
    IMailbox public mailbox;
    mapping(bool=>bytes32) public destinationAddress;
    bytes32 public oracleAddress;
    mapping(bool=>uint32) public destinationChainIds;

    // zk Variables
    UltraVerifier public zkVerifier; 
    bool public isZkVerificationEnabled;

    constructor(uint256 _initialGameId, IMailbox _mailbox) 
    {
        // Hyperlane Initializations
        mailbox = _mailbox;

        // LuffyProtocol Initializations
        isZkVerificationEnabled = true;
        gameCounter = _initialGameId;
        owner=msg.sender;

        // zk Initializations
        zkVerifier=new UltraVerifier();

    }

    event GamePlayerIdRemappingSet(uint256 gameId, string remapping);
    event PlayersMetadataUpdated(uint256 playersMetadataLength, string[] playersMetadata);
    event SquadRegistered(uint256 gameweek, bytes32 squadHash, address registrant);
    event PointsClaimed(uint256 gameweek, address claimer, uint256 totalPoints);
    event ResultsFetchInitiated(uint256 gameweek, bytes32 requestId);
    event ResultsPublished(uint256 gameId, bytes32 pointsMerkleRoot, string gameResults);
    event ResultsFetchFailed(uint256 gameweek, bytes32 requestId, bytes error);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAllowedCaller(msg.sender, owner);
        _;
    }

    modifier onlyMailbox() {
        if(msg.sender != address(mailbox)) revert NotMailbox(msg.sender);
        _;
    }

    function setOracleAddress(bytes32 _oracleAddress) public onlyOwner{
        oracleAddress = _oracleAddress;
    }

    function setPlayerIdRemmapings(uint256 _gameId, string memory _remapping) public onlyOwner {
        playerIdRemappings[_gameId] = _remapping;
        isSelectSquadEnabled[_gameId] = true;
        gameCounter=_gameId;
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

    function claimPoints(uint256 gameId, uint256 totalPoints, bytes calldata _proof) public payable {
        if(pointsMerkleRoot[gameId] == bytes32(0)) revert ResultsNotPublished(gameId);

        if(isZkVerificationEnabled){
            bytes32[] memory _publicInputs=new bytes32[](2);
            _publicInputs[0]=pointsMerkleRoot[gameId];
            _publicInputs[1]=gameToSquadHash[gameId][msg.sender];
            _publicInputs[2]= bytes32(totalPoints);
            try zkVerifier.verify(_proof, _publicInputs)
            {
               gamePoints[gameId][msg.sender] = totalPoints;
                emit PointsClaimed(gameCounter, msg.sender, totalPoints);
            }catch{
                revert ZeroKnowledgeVerificationFailed();
            }
        } else{
            gamePoints[gameId][msg.sender] = totalPoints;
            emit PointsClaimed(gameCounter, msg.sender, totalPoints);
        }
    }

    function handle(uint32 , bytes32 _sender, bytes calldata _message) external payable onlyMailbox{
        if(_sender != oracleAddress) revert NotAllowedCrosschainCaller(_sender);
        (uint256 _gameId, bytes32 _pointsMerkleRoot, string memory _gameResults) = abi.decode(_message, (uint256, bytes32, string));
        pointsMerkleRoot[_gameId] = _pointsMerkleRoot;
        gameResults[_gameId] = _gameResults;
        emit ResultsPublished(_gameId, _pointsMerkleRoot, _gameResults);
    }


    // Testing helpers
    function setupDestinationAddresses(uint32[2] memory _destinationChainIds,  bytes32[2] memory _destinationAddresses) public onlyOwner {
        destinationChainIds[false] = _destinationChainIds[0];
        destinationChainIds[true] = _destinationChainIds[1];
        destinationAddress[false] = _destinationAddresses[0];
        destinationAddress[true] = _destinationAddresses[1];
    }
    function setSelectSquadEnabled(uint256 _gameId, bool _isSelectSquadEnabled) public onlyOwner {
        isSelectSquadEnabled[_gameId] = _isSelectSquadEnabled;
    }

    function setGameCounter(uint256 _gameCounter) public onlyOwner {
        gameCounter = _gameCounter;
    }

    function setPointsMerkleRoot(uint256 _gameweek, bytes32 _pointsMerkleRoot) public onlyOwner {
        pointsMerkleRoot[_gameweek] = _pointsMerkleRoot;
    }

    function setZkVerificationEnabled(bool _isZkVerificationEnabled) public onlyOwner {
        isZkVerificationEnabled = _isZkVerificationEnabled;
    }
    
}