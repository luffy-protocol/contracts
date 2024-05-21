// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

abstract contract Randomness is VRFV2PlusWrapperConsumerBase, ConfirmedOwner{

    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;
    uint32 public vrfCallbackGasLimit = 400_000;

    constructor(address _vrfWrapper) VRFV2PlusWrapperConsumerBase(_vrfWrapper){}

     function _requestRandomness() internal returns (uint256,uint256) {
       return requestRandomnessPayInNative(vrfCallbackGasLimit, requestConfirmations, numWords, "");
    }

    function setCallbackGasLimit(uint32 _vrfCallbackGasLimit) external onlyOwner {
        vrfCallbackGasLimit = _vrfCallbackGasLimit;
    }   

    function setRequestConfirmations(uint16 _requestConfirmations) external onlyOwner {
        requestConfirmations = _requestConfirmations;
    }

    function setNumWords(uint32 _numWords) external onlyOwner {
        numWords = _numWords;
    }

    function getRandomnessPriceInNative() public view returns (uint256) {
        return i_vrfV2PlusWrapper.calculateRequestPriceNative(vrfCallbackGasLimit);
    }

}

