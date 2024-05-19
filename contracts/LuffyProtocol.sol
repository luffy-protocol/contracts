// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./abstract/Predictions.sol";
import "./abstract/ZeroKnowledge.sol";
import "./abstract/PointsCompute.sol";
import "./abstract/Automation.sol";
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


contract LuffyProtocol is PointsCompute, ZeroKnowledge, Predictions, Automation{

    error InvalidAutomationCaller(address caller);
    error ClaimWindowComplete(uint256 currentTimestamp, uint256 deadline);

    address public sourceChainSelector;

    constructor(address _functionsRouter, string memory _sourceCode, uint64 _subscriptionId, uint64 _sourceChainSelector, bytes32 _donId, address _automationRegistry, AggregatorV3Interface[3] memory _priceFeeds) Automation(_automationRegistry) PointsCompute(_functionsRouter,_sourceCode,_subscriptionId,_donId) Predictions(_priceFeeds) 
    {
        sourceChainSelector=_sourceChainSelector;
    }

    receive() external payable {
        (bool,bytes )=owner().call{value: msg.value}("");
    }

    fallback() external payable {
        (bool,bytes )=owner().call{value: msg.value}("");
    }

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

    function performUpkeep(bytes calldata performData) external override onlyOwnerOrAutomation(1) {
        (bytes32 _requestId, bytes memory response) = abi.decode(performData, (bytes32, bytes));
        (bytes32 _merkleRoot, string memory _pointsIpfsHash)=abi.decode(response, (bytes32, string));

        uint256 _gameId=requestToGameId[_requestId];
        results[_gameId]=Results(_pointsIpfsHash, _merkleRoot, block.timestamp);
        emit OracleResultsPublished(_requestId, _gameId, _merkleRoot, _pointsIpfsHash);
    }

    function claimPoints(uint256 _gameId, uint256[11] memory playerIds, bytes memory proof) public {
        if(block.timestamp > results[_gameId].publishedTimestamp + 2 days) revert ClaimWindowComplete(block.timestamp, results[_gameId].publishedTimestamp + 2 days);

        // TODO: Pass playerIds in.
        bytes32[] memory _publicInputs=new bytes32[](2);
        
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

}