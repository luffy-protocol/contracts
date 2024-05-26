// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./abstract/Predictions.sol";
import "./abstract/ZeroKnowledge.sol";
import "./abstract/PointsCompute.sol";
import "./abstract/Automation.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Chailnink Integrations [6/6]
// 1. Chainlink Functions - DONE Sub Id - preconfigured
// 2. Chainlink Data Feeds - DONE No configurations
// 3. Chainlink VRF - DONE No configurations | Direct Funding
// 4. Chainlink CCIP - DONE No configurations | Direct Funding 
// 5. Chainlink Log Trigger Automation - DONE Need to configure sub id
// 6. Chainlink TIme Based Automation - DONE Need to configure sub id

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


    struct Game{
        uint256 gameweek;
        uint256[] gameIds;
        string[] remappings;
        uint256 resultsTriggersIn;
    }

    error SelectSquadDisabled(uint256 gameId);
    error InvalidAutomationCaller(address caller);
    error ClaimWindowComplete(uint256 currentTimestamp, uint256 deadline);
    error ClaimWindowInComplete(uint256 currentTimestamp, uint256 deadline);
    error PanicClaimError();

    uint256 public latestGameweek;

    uint8 public prevDonHostedSecretsSlotID;
    uint64 public prevDonHostedSecretsVersion;
    mapping(uint256=>Game) public games;
    mapping(address=>uint256) public claimmables;
    mapping(uint256=>mapping(address=>uint256)) public rankings;
    mapping(uint256=>mapping(address=>uint256)) public winnings;
    mapping(uint256=>bool) public gameIdsToRemappingsSet;

    struct ConstructorParams{
        string sourceCode;
        address vrfWrapper;
        address ccipRouter;
        address usdcToken;
        address linkToken;
        uint256[2] upKeepIds;
        AggregatorV3Interface[2] priceFeeds;
    }

    constructor(ConstructorParams memory _params) Predictions( _params.vrfWrapper,  _params.ccipRouter,  _params.usdcToken,  _params.linkToken, _params.priceFeeds) PointsCompute(_params.sourceCode) ConfirmedOwner(msg.sender) Automation(_params.upKeepIds) {}

    modifier onlyOwnerOrAutomation(uint8 _automation){
        address forwarderAddress=getForwarderAddress(_automation);
        if(msg.sender!=owner()&&msg.sender!=forwarderAddress) revert InvalidAutomationCaller(msg.sender);
        _;
    }

    receive() external payable {
       (bool success, ) = owner().call{value: msg.value}("");
       require(success, "Transfer Failed");
    }

    fallback() external payable {
       (bool success, ) = owner().call{value: msg.value}("");
       require(success, "Transfer Failed");
    }
    
    event PointsClaimed(uint256 gameid, address claimer, bytes32[11] playerIds, uint256 totalPoints);
    event RewardsClaimed(uint256 gameId, address claimer, uint256 value, uint256 position);
    event RewardsWithdrawn(address claimer, uint256 value);
    event GamePlayerIdRemappingSet(uint256 gameweek, uint256[] gameIds, string[]  remappings, uint256 resultsTriggersIn);


    function setPlayerIdRemappings(uint256 gameweek, uint256[] memory gameIds, string[] memory remappings, uint256 resultsTriggersIn) public{
        games[gameweek]=Game(gameweek, gameIds, remappings, resultsTriggersIn);
        for(uint256 i=0; i<gameIds.length; i++) gameIdsToRemappingsSet[gameIds[i]]=true;
        latestGameweek=gameweek;
        emit GamePlayerIdRemappingSet(gameweek, gameIds, remappings, resultsTriggersIn);
    }

    function makeSquadAndPlaceBet(uint256 _gameId, bytes32 _squadHash, uint256 _amount, uint8 _token, uint8 _captain, uint8 _viceCaptain) external payable{
        if(!gameIdsToRemappingsSet[_gameId]) revert SelectSquadDisabled(_gameId);
        _makeSquadAndPlaceBet(_gameId, _squadHash, _amount, _token, _captain, _viceCaptain);
    }

    function makeSquadAndPlaceBetRandom(uint256 _gameId, bytes32 _squadHash, uint256 _amount, uint8 _token) external payable{
        if(!gameIdsToRemappingsSet[_gameId]) revert SelectSquadDisabled(_gameId);
        _makeSquadAndPlaceBetRandom(_gameId, _squadHash, _amount, _token);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        ) 
    {
        (uint256 gameId, address player, bytes32 squadHash, uint8 token, uint8 captain, uint8 viceCaptain, bool isRandom) = abi.decode(any2EvmMessage.data, (uint256, address, bytes32, uint8, uint8, uint8, bool));
        if(any2EvmMessage.destTokenAmounts[0].amount < BET_AMOUNT_IN_USDC) revert InsufficientBetAmount(player, token, any2EvmMessage.destTokenAmounts[0].amount, any2EvmMessage.destTokenAmounts[0].amount);
        if(!gameIdsToRemappingsSet[gameId]) revert SelectSquadDisabled(gameId);

        gameToPrediction[gameId][player] = Prediction(squadHash, any2EvmMessage.destTokenAmounts[0].amount, token, captain, viceCaptain, isRandom);
        emit CrosschainReceived(any2EvmMessage.messageId);
        emit BetPlaced(gameId,  player, gameToPrediction[gameId][player]);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData )
    {
        if(block.timestamp > games[latestGameweek].resultsTriggersIn) {
            if(prevDonHostedSecretsSlotID!=0 && prevDonHostedSecretsVersion != 0){
                upkeepNeeded = true;
                performData=abi.encode(bytes32(0), "", false);
            }
        }
    }

    function triggerFetchResults(uint256 gameweek, uint8 donHostedSecretsSlotID, uint64 donHostedSecretsVersion) public onlyOwnerOrAutomation(0) {
        for(uint256 i=0; i<games[gameweek].gameIds.length; i++) _triggerCompute(games[gameweek].gameIds[i], games[gameweek].remappings[i], donHostedSecretsSlotID, donHostedSecretsVersion);
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        latestResponse = response;
        latestError = err;
        if(response.length==0) emit OracleResponseFailed(requestId, err);
        else emit OracleResponseSuccess(requestId, response, true);
    }

    function performUpkeep(bytes calldata performData) external override onlyOwnerOrAutomation(1) {
        (bytes32 _requestId, bytes memory response, bool isFunctions) = abi.decode(performData, (bytes32, bytes, bool));
        if(isFunctions)
        {   
            (bytes32 _merkleRoot, string memory _pointsIpfsHash)=abi.decode(response, (bytes32, string));

            uint256 _gameId=requestToGameId[_requestId];
            results[_gameId]=Results(_pointsIpfsHash, _merkleRoot, block.timestamp);
            emit OracleResultsPublished(_requestId, _gameId, _merkleRoot, _pointsIpfsHash);
        }else{
            triggerFetchResults(latestGameweek, prevDonHostedSecretsSlotID, prevDonHostedSecretsVersion);
        }
    }

    function claimPoints(uint256 _gameId, bytes32[11] memory _playerIds, uint256 _totalPoints, bytes memory _proof) external {
        if(block.timestamp > results[_gameId].publishedTimestamp + 2 days) revert ClaimWindowComplete(block.timestamp, results[_gameId].publishedTimestamp + 2 days);
        bytes32[] memory _publicInputs=new bytes32[](47);
        Prediction memory _prediction=gameToPrediction[_gameId][msg.sender];
        bytes32 _squadHash=_prediction.squadHash;
        // captain, vice captain, isRandom, playerIds, squadHash, claimed player points
        _publicInputs[0]=bytes32(uint256(_prediction.captain));
        _publicInputs[1]=bytes32(uint256(_prediction.viceCaptain));
        _publicInputs[2]=bytes32(_prediction.isRandom?uint256(1):uint256(0));
        for(uint i=0; i<11;i++) _publicInputs[3+i]=_playerIds[i];
        for(uint i=0; i<32;i++) _publicInputs[14+i]=bytes32(uint256(uint8(_squadHash[i])));
        _publicInputs[46]=bytes32(_totalPoints);
        _verifyProof(_proof, _publicInputs);
        emit PointsClaimed(_gameId, msg.sender, _playerIds, _totalPoints);
    }

    function claimRewards(uint256 _gameId, address _player, uint256 _amountInWei, uint256 _position) public onlyOwner{
        if(block.timestamp < results[_gameId].publishedTimestamp + 2 days) revert ClaimWindowInComplete(block.timestamp, results[_gameId].publishedTimestamp + 2 days);

        claimmables[_player]+=_amountInWei;
        rankings[_gameId][_player]=_position;
        winnings[_gameId][_player]=_amountInWei;

        emit RewardsClaimed(_gameId, _player, _amountInWei, _position);
    }

    function withdrawRewards() external{
        if(claimmables[msg.sender]>0) _withdrawRewards();
    }

    function _withdrawRewards() internal{
        if(IERC20(USDC_TOKEN).balanceOf(address(this))<claimmables[msg.sender]) revert PanicClaimError();
        uint256 value=claimmables[msg.sender];
        claimmables[msg.sender]=0;
        IERC20(USDC_TOKEN).transferFrom(address(this), msg.sender, value);
        emit RewardsWithdrawn(msg.sender, value);
    }

    function claimAndWithdrawRewards(uint256 _gameId, address _player, uint256 _amountInWei, uint256 _position) external onlyOwner{
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

    function setDonHostedSecrets(uint8 _donHostedSecretsSlotID, uint64 _donHostedSecretsVersion) external onlyOwner{
        prevDonHostedSecretsSlotID=_donHostedSecretsSlotID;
        prevDonHostedSecretsVersion=_donHostedSecretsVersion;
    }

    function zmakeSquadTest(uint256 _gameId, address _player, Prediction memory _prediction) external {
        emit BetPlaced(_gameId, _player, _prediction);
    }

    function zpostResultsTest(bytes32 _requestId, uint256 _gameId, bytes32 _merkleRoot, string memory _pointsIpfsHash) external{
        emit OracleResultsPublished(_requestId, _gameId, _merkleRoot, _pointsIpfsHash);
    }

    function zclaimPointsTest(uint256 _gameId, address _claimer,bytes32[11] memory _playerIds, uint256 _totalPoints) external{
        emit PointsClaimed(_gameId, _claimer, _playerIds, _totalPoints);
    }

    function zclaimRewardsTest(uint256 _gameId, address _claimer, uint256 _amount, uint256 _position) external{
        emit RewardsClaimed(_gameId, _claimer, _amount, _position);
    }

    function zwithdrawRewardsTest(address _claimer, uint256 _amount) external{
        emit RewardsWithdrawn(_claimer, _amount);
    }

    function zsetPlayerIdRemmapings(uint256 gameweek, uint256[] memory gameIds, string[] memory remappings, uint256 resultsTriggersIn) external  {
        emit GamePlayerIdRemappingSet(gameweek, gameIds, remappings, resultsTriggersIn);
    }

}