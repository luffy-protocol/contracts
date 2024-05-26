// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;


import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import "../interface/ILogAutomation.sol";

abstract contract PointsCompute is FunctionsClient, ILogAutomation {

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
    mapping(bytes32=>uint256) public requestToGameId;
    mapping(uint256=>Results) public results;

    constructor(string memory _sourceCode) FunctionsClient(0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0)
    {
        sourceCode=_sourceCode;
    }

    event OracleResponseSuccess(bytes32 requestId, bytes response, bool isFunction);
    event OracleResponseFailed(bytes32 requestId, bytes err);
    event OracleRequestSent(bytes32 requestId, uint256 gameId);
    event OracleResultsPublished(bytes32 requestId, uint256 gameId, bytes32 pointsMerkleRoot, string pointsIpfsHash);

}