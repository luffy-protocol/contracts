// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interface/ILogAutomation.sol";

abstract contract PointsCompute is FunctionsClient, ILogAutomation {
    using FunctionsRequest for FunctionsRequest.Request;  
    using Strings for uint256;

    struct Results{
        string ipfsHash;
        bytes32 merkleRoot;
        uint256 publishedTimestamp;
    }

    
    bytes32 public constant DON_ID=0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
    uint64 public constant SUBSCRIPTION_ID=8378;

    string public sourceCode;
    bytes32 public latestRequestId;
    bytes public latestResponse;
    bytes public latestError;
    uint32 public oracleCallbackGasLimit = 300000;
    mapping(bytes32=>uint256) public requestToGameId;
    mapping(uint256=>Results) public results;

    address public constant FUNCTIONS_ROUTER=0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0; // AvalancheFuji Chainlink Functions Router

    constructor(string memory _sourceCode) FunctionsClient(FUNCTIONS_ROUTER)
    {
        sourceCode=_sourceCode;
    }

    event OracleResponseSuccess(bytes32 requestId, bytes response);
    event OracleResponseFailed(bytes32 requestId, bytes err);
    event OracleRequestSent(bytes32 requestId, uint256 gameId);
    event OracleResultsPublished(bytes32 requestId, uint256 gameId, bytes32 pointsMerkleRoot, string pointsIpfsHash);


    function _triggerCompute(uint256 gameId, string memory remapping, uint8 donHostedSecretsSlotID, uint64 donHostedSecretsVersion) internal returns(bytes32){
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        req.addDONHostedSecrets(
            donHostedSecretsSlotID,
            donHostedSecretsVersion
        );
        string[] memory args= new string[](2);
        args[0]=gameId.toString();
        args[1]=remapping;
        if (args.length > 0) req.setArgs(args);
        latestRequestId = _sendRequest(
            req.encodeCBOR(),
            SUBSCRIPTION_ID,
            oracleCallbackGasLimit,
            DON_ID
        );
        emit OracleRequestSent(latestRequestId, gameId);
        requestToGameId[latestRequestId]=gameId;
        return latestRequestId;
    }

}