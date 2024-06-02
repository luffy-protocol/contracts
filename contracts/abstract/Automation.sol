// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IKeeperRegistryMaster} from "@chainlink/contracts/src/v0.8/automation/interfaces/v2_1/IKeeperRegistryMaster.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import "../interface/ILogAutomation.sol";

abstract contract Automation is AutomationCompatibleInterface, ILogAutomation, ConfirmedOwner{
    
    uint256[2] public upKeepIds; // 0 - Custom Logic Trigger, 1 - Log Trigger
    address[2] public forwarderAddresses;  // 0 - Custom Logic Trigger, 1 - Log Trigger

    constructor(){
        upKeepIds[0]=58387336616451823836734822744286210528343491445611152550443089243189960990986;
        upKeepIds[1]=42777266604767705378881328016196847279435767347742105064170763126637428887845;
        forwarderAddresses[0]=0xeBA520bB98331Afc436bc03Fd6536AeD38FC8Cde;
        forwarderAddresses[1]=0x734Dfb1809580f41F7f6cB11414df4f2d95f5d93;
    }

    function setTimeTriggerAutomation(uint256 _upKeepId) external onlyOwner{
        upKeepIds[0]=_upKeepId;
    }

    function setLogTriggerAutomation(uint256 _upKeepId) external onlyOwner{
        upKeepIds[1]=_upKeepId;
    }

    function setForwarderAddress(uint8 _automation, address _forwarder) external onlyOwner{
        forwarderAddresses[_automation]=_forwarder;
    }

    function getForwarderAddress(uint8 _automation) public view returns(address){
        return forwarderAddresses[_automation];
    }   
              
    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        performData = log.data;
    }



}