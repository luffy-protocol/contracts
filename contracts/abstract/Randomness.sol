// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {IVRFV2PlusWrapper} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

abstract contract Randomness is VRFV2PlusWrapperConsumerBase, ConfirmedOwner{

    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;
    uint32 public vrfCallbackGasLimit;
    IVRFV2PlusWrapper public immutable VRF_WRAPPER;

    constructor(address _vrfWrapper, uint32 _vrfCallbackGasLimit) VRFV2PlusWrapperConsumerBase(_vrfWrapper){
        VRF_WRAPPER = IVRFV2PlusWrapper(_vrfWrapper);  
        vrfCallbackGasLimit=_vrfCallbackGasLimit;
    }

    function request() payable external returns(uint256, uint256){
        return _requestRandomness();
    }

    function _requestRandomness() internal returns (uint256,uint256) {
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
        );
       return requestRandomnessPayInNative(vrfCallbackGasLimit, requestConfirmations, numWords, extraArgs);
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

    function getRandomnessPriceInNative(uint256 _gasPriceInWei) public view returns (uint256) {
        return VRF_WRAPPER.estimateRequestPriceNative(vrfCallbackGasLimit, numWords, _gasPriceInWei);
    }
}

