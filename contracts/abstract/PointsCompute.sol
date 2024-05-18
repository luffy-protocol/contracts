// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract PointsCompute is FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;  
    using Strings for uint256;

    
    bytes32 public donId;
    address public functionsRouter;
    address public upkeepContract;
    string public sourceCode;
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    uint32 public s_callbackGasLimit = 300000;
    uint64 public s_subscriptionId;


    constructor(address _functionsRouter, string memory _sourceCode, uint64 _subscriptionId, bytes32 _donId) FunctionsClient(_functionsRouter)
    {
        functionsRouter=_functionsRouter;
        sourceCode=_sourceCode;
        s_subscriptionId=_subscriptionId;
        donId=_donId;
    }


}