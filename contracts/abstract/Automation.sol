// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IKeeperRegistryMaster} from "@chainlink/contracts/src/v0.8/automation/interfaces/v2_1/IKeeperRegistryMaster.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "../interface/ILogAutomation.sol";

abstract contract Automation is ILogAutomation, ConfirmedOwner{
    
    IKeeperRegistryMaster public automationRegistry=IKeeperRegistryMaster(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    
    uint256[2] public upKeepIds; // 0 - Custom Logic Trigger, 1 - Log Trigger

    constructor(uint256[2] memory _upKeepIds){
        upKeepIds=_upKeepIds;
    }

    function setTimeTriggerAutomation(uint256 _upKeepId) external onlyOwner{
        upKeepIds[0]=_upKeepId;
    }

    function setLogTriggerAutomation(uint256 _upKeepId) external onlyOwner{
        upKeepIds[1]=_upKeepId;
    }

    function getForwarderAddress(uint8 _automation) public view returns(address){
        return automationRegistry.getForwarder(upKeepIds[_automation]);
    }   
              
    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        performData = log.data;
    }

}