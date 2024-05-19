// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./abstract/PriceFeeds.sol";
import "./abstract/ZeroKnowledge.sol";
import "./abstract/PointsCompute.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
// 1. Set player id remappings manually for each game along with their start times.
// 2. Choose squad for a game and place bet. Handle Crosschain bets too.
// 3. Once match gets ended, Chainlink Time based automation is triggers the Chainlink Functions.
// 4. Chainlink Functions fetches the results and triggers a log
// 5. Chainlink Log Trigger Automation executes the code logic to assign the squad points ipfs hash and merkle root.
// 6. Users will call claim points by verifying the zero knowledge proof.
// 7. They will wait for 48 hours and claim the rewards based on the position in the leaderboard.


contract LuffyProtocol is PointsCompute, ZeroKnowledge, PriceFeeds, ConfirmedOwner{

    uint256 public betAmount = 5 * 10 ** 8;
    mapping(address=>bool) public whitelistedBetTokens;

    mapping(uint256=>mapping(address=>bytes32)) public gameToSquadHash;
    mapping(uint256=>mapping(address=>uint256)) public gamePoints;
    mapping(uint256=>string) public playerIdRemappings;
    string[] public playersMetadata;

    constructor(address _functionsRouter, string memory _sourceCode, uint64 _subscriptionId, bytes32 _donId, AggregatorV3Interface[3] memory _priceFeeds) PointsCompute(_functionsRouter,_sourceCode,_subscriptionId,_donId) PriceFeeds(_priceFeeds) ConfirmedOwner(msg.sender) 
    {}

    modifier isBetTokenWhitelisted(uint8 _token){
        address _betToken=address(priceFeeds[_token]);

        if(!whitelistedBetTokens[_betToken]) revert InvalidBetToken(_betToken);
        _;
    }


    function whitelistBetTokens(address[] memory _betTokens) public onlyOwner {
        for(uint256 i=0; i<_betTokens.length; i++){
            whitelistedBetTokens[_betTokens[i]] = true;
        }
        emit Events.NewTokensWhitelisted(_betTokens);
    }





    function makeSquadAndPlaceBetETH(uint256 _gameId, bytes32 _squadHash) public payable{
        if(playerIdRemappings[_gameId].length>0) revert SelectSquadDisabled(_gameId);

        uint256 betAmountInUSD=getValueInUSD(msg.value,0);
        if(betAmountInUSD < betAmount) revert InsufficientBetAmount(msg.sender, address(0), betAmountInUSD, msg.value);
        _makeSquad(_gameId, _squadHash, address(0));
    }

    function makeSquadAndPlaceBetToken(uint256 _gameId, bytes32 _squadHash, uint8 _token, uint256 betAmountInWei) isBetTokenWhitelisted(_token) public {
        if(playerIdRemappings[_gameId].length>0) revert SelectSquadDisabled(_gameId);

        address betToken=address(priceFeeds[_token]);
        if(IERC20(betToken).allowance(msg.sender, address(this)) < betAmountInWei) revert InsufficientAllowance(msg.sender, _token, betAmountInWei);

        uint256 betAmountInUSD=getValueInUSD(betAmountInWei, _token);
        if(betAmountInUSD < betAmount) revert InsufficientBetAmount(msg.sender, betToken, betAmountInUSD, betAmountInWei);

        IERC20(betToken).transferFrom(msg.sender, address(this), betAmountInWei);
        _makeSquad(_gameId, _squadHash, betToken);
    }

    function  _makeSquad(uint256 _gameId, bytes32 _squadHash, address token) internal {
        gameToSquadHash[_gameId][msg.sender] = _squadHash;
        emit Events.BetPlaced(_gameId, _squadHash, msg.sender, token);
    }

    // function claimPoints(uint256 _gameId, uint256 totalPoints, bytes calldata _proof) public {
    //     // Enable in Production
    //     // if(isSelectSquadEnabled[_gameId]) revert SelectSquadDisabled(_gameId);
    //     if(pointsMerkleRoot[_gameId] == bytes32(0)) revert ResultsNotPublished(_gameId);

    //     if(isZkVerificationEnabled){
    //         bytes32[] memory _publicInputs=new bytes32[](2);
    //         _publicInputs[0]=pointsMerkleRoot[_gameId];
    //         _publicInputs[1]=gameToSquadHash[_gameId][msg.sender];
    //         _publicInputs[2]= bytes32(totalPoints);
           
    //     } else{
    //         gamePoints[_gameId][msg.sender] = totalPoints;
    //         emit Events.PointsClaimed(_gameId, msg.sender, totalPoints);
    //     }
    // }

    // Chainlink Functions
    // function triggerFetchpointsIpfsHash(uint256 _gameId, uint8 donHostedSecretsSlotID, uint64 donHostedSecretsVersion) external onlyOwner{
    //     FunctionsRequest.Request memory req;
    //     req.initializeRequestForInlineJavaScript(sourceCode);
    //     req.addDONHostedSecrets(
    //         donHostedSecretsSlotID,
    //         donHostedSecretsVersion
    //     );
    //     string[] memory args= new string[](2);
    //     args[0]=Strings.toString(_gameId);
    //     args[1]=playerIdRemappings[_gameId];
    //     latestRequestId = _sendRequest(
    //         req.encodeCBOR(),
    //         functionsSubscriptionId,
    //         oracleCallbackGasLimit,
    //         donId
    //     );
    //     requestToGameId[latestRequestId] = _gameId;
    //     emit Events.ResultsFetchInitiated(_gameId, latestRequestId);
    // }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        latestResponse = response;
        latestError = err;
        if(response.length==0) emit OracleResponseFailed(requestId, err);
        else emit OracleResponseSuccess(requestId, response);
    } 

          
    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        performData = log.data;
    }

    function performUpkeep(bytes calldata performData) external override {
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