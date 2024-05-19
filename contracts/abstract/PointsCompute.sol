// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interface/ILogAutomation.sol";

abstract contract PointsCompute is FunctionsClient, ILogAutomation {
    using FunctionsRequest for FunctionsRequest.Request;  
    using Strings for uint256;

    
    bytes32 public donId;
    address public functionsRouter;
    string public sourceCode;
    bytes32 public latestRequestId;
    bytes public latestResponse;
    bytes public latestError;
    uint32 public oracleCallbackGasLimit = 300000;
    uint64 public functionsSubscriptionId;
    mapping(bytes32=>uint256) public requestToGameId;
    mapping(uint256=>string) public pointsIpfsHash;
    mapping(uint256=>bytes32) public pointsMerkleRoot;

    constructor(address _functionsRouter, string memory _sourceCode, uint64 _subscriptionId, bytes32 _donId) FunctionsClient(_functionsRouter)
    {
        functionsRouter=_functionsRouter;
        sourceCode=_sourceCode;
        functionsSubscriptionId=_subscriptionId;
        donId=_donId;
    }

    event OracleResponseSuccess(bytes32 requestId, bytes response);
    event OracleResponseFailed(bytes32 requestId, bytes err);
    event OracleRequestSent(bytes32 requestId, uint256 gameId);
    event OracleResultsPublished(bytes32 requestId, uint256 gameId, bytes32 pointsMerkleRoot, string pointsIpfsHash);


    function _triggerCompute(uint256 gameId, string[] memory args, uint8 donHostedSecretsSlotID, uint64 donHostedSecretsVersion) internal returns(bytes32){
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        req.addDONHostedSecrets(
            donHostedSecretsSlotID,
            donHostedSecretsVersion
        );
        if (args.length > 0) req.setArgs(args);
        latestRequestId = _sendRequest(
            req.encodeCBOR(),
            functionsSubscriptionId,
            oracleCallbackGasLimit,
            donId
        );
        emit OracleRequestSent(latestRequestId, gameId);
        requestToGameId[latestRequestId]=gameId;
        return latestRequestId;
    }


//    function fulfillRequest(
//         bytes32 requestId,
//         bytes memory response,
//         bytes memory err
//     ) internal override {
//         if (latestRequestId != requestId) {
//             revert UnexpectedRequestID(requestId);
//         }
//         latestResponse = response;
//         latestError = err;
//         emit Response(requestId, latestResponse, latestError);
//     }

}