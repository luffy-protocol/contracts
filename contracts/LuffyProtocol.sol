// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./abstract/PriceFeeds.sol";
import "./abstract/ZeroKnowledge.sol";
import "./abstract/PointsCompute.sol";
import "./abstract/Automation.sol";
import "./utils/Errors.sol";
import "./utils/Events.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";


// Chainlink Functions
// Chainlink Data Feeds
// Chainlink VRF
// Chainlink CCIP
// Chainlink Log Trigger Automation
// Chainlink TIme Based Automation

// Step 1: Register Squad
// Step 2: Receive cross chain transactions
//  - Receive bet amount in USD
//  - 
// Step 3: Chainlink Time based Automation
// Step 4: Chainlink Log Trigger Auomation
// Step 5: Chainlink Price Feeds to convert bet amount
// Chainlnk VRF to 


// Things that happen in this contract
// Intial setup: Set upkeep ids for both automation
// 1. Set player id remappings manually for each game along with their start times. DONE
// 2. Choose squad for a game and place bet. DONE
//  - Handle Crosschain bets too. PENDING
// 3. Once match gets ended, Chainlink Time based automation is triggers the Chainlink Functions. DONE
// 4. Chainlink Functions fetches the results and triggers a log DONE
// 5. Chainlink Log Trigger Automation executes the code logic to assign the squad points ipfs hash and merkle root. DONE
// 6. Users will call claim points by verifying the zero knowledge proof.
// 7. They will wait for 48 hours and claim the rewards based on the position in the leaderboard.


contract LuffyProtocol is PointsCompute, ZeroKnowledge, PriceFeeds, ConfirmedOwner, Automation{


    constructor(address _functionsRouter, string memory _sourceCode, uint64 _subscriptionId, bytes32 _donId, address _automationRegistry, AggregatorV3Interface[3] memory _priceFeeds) Automation(_automationRegistry) PointsCompute(_functionsRouter,_sourceCode,_subscriptionId,_donId) PriceFeeds(_priceFeeds) ConfirmedOwner(msg.sender) 
    {}


    modifier onlyOwnerOrAutomation(uint8 _automation){
        address forwarderAddress=getForwarderAddress(_automation);
        if(msg.sender!=owner()&&msg.sender!=forwarderAddress) revert InvalidAutomationCaller(msg.sender);
        _;
    }



    function triggerFetchResults(uint256 gameId, uint8 donHostedSecretsSlotID, uint64 donHostedSecretsVersion) external onlyOwnerOrAutomation(0) {
        _triggerCompute(gameId,playerIdRemappings[gameId], donHostedSecretsSlotID, donHostedSecretsVersion);
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        latestResponse = response;
        latestError = err;
        if(response.length==0) emit OracleResponseFailed(requestId, err);
        else emit OracleResponseSuccess(requestId, response);
    } 

    function performUpkeep(bytes calldata performData) external override onlyOwnerOrAutomation(1){
        (bytes32 _requestId, bytes memory response) = abi.decode(performData, (bytes32, bytes));
        (bytes32 _merkleRoot, string memory _pointsIpfsHash)=abi.decode(response, (bytes32, string));

        uint256 _gameId=requestToGameId[_requestId];
        pointsIpfsHash[_gameId]=_pointsIpfsHash;
        pointsMerkleRoot[_gameId]=_merkleRoot;
        emit OracleResultsPublished(_requestId, _gameId, _merkleRoot, _pointsIpfsHash);
    }

    // Only Owner

    function setBetAmountInUSD(uint256 _amount) public onlyOwner {
        betAmount = _amount;
        emit Events.BetAmountSet(_amount);
    }

    function setPlayerIdRemmapings(uint256 _gameId, string memory _remapping) public onlyOwner {
        playerIdRemappings[_gameId] = _remapping;
        emit Events.GamePlayerIdRemappingSet(_gameId, _remapping);
    }

    // Testing helpers

    function updateSourceCode(string memory _sourceCode) public onlyOwner {
        sourceCode=_sourceCode;
    }

    // function setZkVerificationEnabled(bool _isZkVerificationEnabled) public onlyOwner {
    //     isZkVerificationEnabled = _isZkVerificationEnabled;
    // }

    function setpointsIpfsHash(uint256 _gameId, string memory _pointsIpfsHash, bytes32 _pointsMerkleRoot) public onlyOwner {
        pointsIpfsHash[_gameId] = _pointsIpfsHash;
        pointsMerkleRoot[_gameId] = _pointsMerkleRoot;
        emit Events.ResultsPublished(_gameId, _pointsMerkleRoot, _pointsIpfsHash);
    }
    
}