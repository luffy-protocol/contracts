

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


import {UltraVerifier} from "./zk/dumb.sol";
error ZeroKnowledgeVerificationFailed();

contract LuffyCrosschain{

    event PointsClaimed();


    UltraVerifier public zkVerifier;

    constructor(){
        zkVerifier = new UltraVerifier();
    }

    function claim(bytes memory proof ) public{
        bytes32[] memory publicInputs = new bytes32[](0);
            try zkVerifier.verify(proof, publicInputs)
            {
                emit PointsClaimed();
            }catch{
                revert ZeroKnowledgeVerificationFailed();
            }
    }


}