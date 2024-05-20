// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./abstract/Predictions.sol";
import "./abstract/ZeroKnowledge.sol";
import "./abstract/PointsCompute.sol";
import "./abstract/Automation.sol";
import "./utils/Events.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Chailnink Integrations [6/6]
// 1. Chainlink Functions - DONE
// 2. Chainlink Data Feeds - DONE
// 3. Chainlink VRF - PENDING
// 4. Chainlink CCIP - DONE
// 5. Chainlink Log Trigger Automation - DONE
// 6. Chainlink TIme Based Automation - DONE

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
//  - Chainlink VRF. PENDING
// 3. Once match gets ended, Chainlink Time based automation is triggers the Chainlink Functions. DONE
// 4. Chainlink Functions fetches the results and triggers a log DONE
// 5. Chainlink Log Trigger Automation executes the code logic to assign the squad points ipfs hash and merkle root. DONE
// 6. Users will call claim points by verifying the zero knowledge proof. DONE
// 7. They will wait for 48 hours and claim the rewards based on the position in the leaderboard. DONE


contract LuffyProtocol is PointsCompute, ZeroKnowledge, Predictions, Automation{

    error InvalidAutomationCaller(address caller);
    error ClaimWindowComplete(uint256 currentTimestamp, uint256 deadline);
    error ClaimWindowInComplete(uint256 currentTimestamp, uint256 deadline);
    error PanicClaimError();


    mapping(address=>uint256) public claimmables;
    mapping(uint256=>mapping(address=>uint256)) public rankings;
    mapping(uint256=>mapping(address=>uint256)) public winnings;

    struct ConstuctorParams{
        address ccipRouter;
        address functionsRouter;
        address usdcToken;
        address linkToken;
        address automationRegistry;
        AggregatorV3Interface[2] priceFeeds;
        string sourceCode;
        uint64 subscriptionId;
        bytes32 donId;

    }


    constructor(ConstuctorParams memory _params) Automation(_params.automationRegistry) PointsCompute(_params.functionsRouter,_params.sourceCode,_params.subscriptionId,_params.donId) Predictions(_params.ccipRouter, _params.usdcToken, _params.linkToken, _params.priceFeeds) {}

    modifier onlyOwnerOrAutomation(uint8 _automation){
        address forwarderAddress=getForwarderAddress(_automation);
        if(msg.sender!=owner()&&msg.sender!=forwarderAddress) revert InvalidAutomationCaller(msg.sender);
        _;
    }

    receive() external payable {
        (bool success, )=owner().call{value: msg.value}("");
    }

    fallback() external payable {
        (bool success, )=owner().call{value: msg.value}("");
    }
    
    event PointsClaimed(uint256 gameid, address claimer, bytes32 playerIds, uint256 totalPoints);
    event RewardsClaimed(uint256 gameId, address claimer, uint256 value, uint256 position);
    event RewardsWithdrawn(address claimer, uint256 value);

    function setPlayerIdRemmapings(uint256 _gameId, string memory _remapping) public onlyOwner {
        playerIdRemappings[_gameId] = _remapping;
        emit Events.GamePlayerIdRemappingSet(_gameId, _remapping);
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

    function claimPoints(uint256 _gameId, bytes32 _playerIds, uint256 _totalPoints, bytes memory _proof) public {
        if(block.timestamp > results[_gameId].publishedTimestamp + 2 days) revert ClaimWindowComplete(block.timestamp, results[_gameId].publishedTimestamp + 2 days);
        bytes32[] memory _publicInputs=new bytes32[](2);
        _publicInputs[0]=gameToSquadHash[_gameId][msg.sender];
        _publicInputs[1]=bytes32(_totalPoints);
        // _publicInputs[2]=playerIds;
        _verifyProof(_proof, _publicInputs);
        emit PointsClaimed(_gameId, msg.sender, _playerIds, _totalPoints);
    }

    function claimRewards(uint256 _gameId, address _player, uint256 _amountInWei, uint256 _position) public onlyOwner{
        if(block.timestamp < results[_gameId].publishedTimestamp + 2 days) revert ClaimWindowInComplete(block.timestamp, results[_gameId].publishedTimestamp + 2 days);
        // Implement Logic that sets money to claimmables and position in leaderboard

        claimmables[_player]+=_amountInWei;
        rankings[_gameId][_player]=_position;
        winnings[_gameId][_player]=_amountInWei;

        emit RewardsClaimed(_gameId, _player, _amountInWei, _position);
    }

    function withdrawRewards() external{
        if(claimmables[msg.sender]>0) _withdrawRewards();
    }

    function _withdrawRewards() internal{
        if(IERC20(usdcToken).balanceOf(address(this))<claimmables[msg.sender]) revert PanicClaimError();
        uint256 value=claimmables[msg.sender];
        claimmables[msg.sender]=0;
        IERC20(usdcToken).transferFrom(address(this), msg.sender, value);
        emit RewardsWithdrawn(msg.sender, value);
    }

    function claimAndWithdrawRewards(uint256 _gameId, address _player, uint256 _amountInWei, uint256 _position) public onlyOwner{
        claimRewards(_gameId, _player, _amountInWei, _position);
        _withdrawRewards();
    }

    // Testing Helpers for subgraph

    // 1. Set playerId remappings
    // 2. Make predictions and place bets
    // 3. Match results posted on chain
    // 4. Claim points on chain
    // 5. Claim rewards on chain
    // 6. Withdraw rewards on chain

    function zmakeSquadTest(uint256 _gameId, bytes32 _squadHash, address _player, uint256 _amount) public {
        emit BetPlaced(_gameId, _squadHash, _player, _amount);
    }

    function zpostResultsTest(bytes32 _requestId, uint256 _gameId, bytes32 _merkleRoot, string memory _pointsIpfsHash) public{
        emit OracleResultsPublished(_requestId, _gameId, _merkleRoot, _pointsIpfsHash);
    }

    function zclaimPointsTest(uint256 _gameId, address _claimer,bytes32 _playerIds, uint256 _totalPoints) public{
        emit PointsClaimed(_gameId, _claimer, _playerIds, _totalPoints);
    }

    function zclaimRewardsTest(uint256 _gameId, address _claimer, uint256 _amount, uint256 _position) public{
        emit RewardsClaimed(_gameId, _claimer, _amount, _position);
    }

    function zwithdrawRewardsTest(address _claimer, uint256 _amount) public{
        emit RewardsWithdrawn(_claimer, _amount);
    }

    function zsetPlayerIdRemmapings(uint256 _gameId, string memory _remapping) public  {
        emit Events.GamePlayerIdRemappingSet(_gameId, _remapping);
    }


}