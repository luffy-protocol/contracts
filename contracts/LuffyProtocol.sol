// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./abstract/Predictions.sol";
import "./abstract/ZeroKnowledge.sol";
import "./abstract/Automation.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

error SelectSquadDisabled(uint256 gameId);
error InvalidAutomationCaller(address caller);
error ClaimWindowComplete(uint256 currentTimestamp, uint256 deadline);
error ClaimWindowInComplete(uint256 currentTimestamp, uint256 deadline);
error PanicClaimError();

contract LuffyProtocol is FunctionsClient, ZeroKnowledge, Predictions, Automation{
    using FunctionsRequest for FunctionsRequest.Request;  
    using Strings for uint256;
    
    struct Game{
        uint256 gameweek;
        uint256[] gameIds;
        string[] remappings;
        uint256 resultsTriggersIn;
    }

    struct Results{
        string ipfsHash;
        bytes32 merkleRoot;
        uint256 publishedTimestamp;
    }

    
    bytes32 public donId;
    uint64 public subscriptionId;

    string public sourceCode;
    bytes32 public latestRequestId;
    bytes public latestResponse;
    bytes public latestError;
    mapping(bytes32=>uint256) public requestToGameId;
    mapping(uint256=>Results) public results;


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

    constructor(ConstructorParams memory _params) FunctionsClient(0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0) Predictions( _params.vrfWrapper,  _params.ccipRouter,  _params.usdcToken,  _params.linkToken, _params.priceFeeds) ConfirmedOwner(msg.sender) Automation(_params.upKeepIds) {
        sourceCode=_params.sourceCode;
        donId=0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
        subscriptionId=8378;
    }

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

    event OracleResponseSuccess(bytes32 requestId, bytes response, bool isFunction);
    event OracleResponseFailed(bytes32 requestId, bytes err);
    event OracleRequestSent(bytes32 requestId, uint256 gameId);
    event OracleResultsPublished(bytes32 requestId, uint256 gameId, bytes32 pointsMerkleRoot, string pointsIpfsHash);


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

    function triggerFetchResults(uint256 gameweek, uint8 donHostedSecretsSlotID, uint64 donHostedSecretsVersion, bytes[] memory bytesArgs) public onlyOwnerOrAutomation(0) {
        // for(uint256 i=0; i<games[gameweek].gameIds.length; i++){
        //     string[] memory args=new string[](2);
        //     args[0]=games[gameweek].gameIds[i].toString();
        //     args[1]=games[gameweek].remappings[i];
        //     _triggerCompute(sourceCode, "", donHostedSecretsSlotID, donHostedSecretsVersion, args, bytesArgs, SUBSCRIPTION_ID, oracleCallbackGasLimit, DON_ID);
        //     emit OracleRequestSent(latestRequestId, games[gameweek].gameIds[i]);
        //     requestToGameId[latestRequestId]=games[gameweek].gameIds[i];
        // }
    }

    function triggerRequest(uint256 gameId, string memory remapping, uint8 slotId, uint64 version, bytes[] memory bytesArgs) public onlyOwnerOrAutomation(0) {
        string[] memory args=new string[](2);
        args[0] = gameId.toString();
        args[1] = remapping;
        _triggerCompute(sourceCode, "", slotId, version, args, bytesArgs, subscriptionId, 300000, donId);
        emit OracleRequestSent(latestRequestId, gameId);
        requestToGameId[latestRequestId] = gameId;
    }

    function _triggerCompute(
        string memory source,
        bytes memory encryptedSecretsUrls,
        uint8 donHostedSecretsSlotID,
        uint64 donHostedSecretsVersion,
        string[] memory args,
        bytes[] memory bytesArgs,
        uint64 subscriptionId,
        uint32 gasLimit,
        bytes32 donID
    ) internal returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        if (encryptedSecretsUrls.length > 0)
            req.addSecretsReference(encryptedSecretsUrls);
        else if (donHostedSecretsVersion > 0) {
            req.addDONHostedSecrets(
                donHostedSecretsSlotID,
                donHostedSecretsVersion
            );
        }
        if (args.length > 0) req.setArgs(args);
        if (bytesArgs.length > 0) req.setBytesArgs(bytesArgs);
        latestRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );
        return latestRequestId;
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
            bytes[] memory bytesArgs=new bytes[](0);
            triggerFetchResults(latestGameweek, prevDonHostedSecretsSlotID, prevDonHostedSecretsVersion, bytesArgs);
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