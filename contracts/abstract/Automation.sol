// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IKeeperRegistryMaster} from "@chainlink/contracts/src/v0.8/automation/interfaces/v2_1/IKeeperRegistryMaster.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "../interface/ILogAutomation.sol";

abstract contract Automation is ILogAutomation, ConfirmedOwner{
    
    IKeeperRegistryMaster public automationRegistry;
    uint256[2] public upKeepIds; // 0 - Time Trigger, 1 - Log Trigger

    constructor(address _automationRegistry) 
    {
        automationRegistry=IKeeperRegistryMaster(_automationRegistry); 
    }

    function setUpKeepIds(uint256[2] memory _upKeepIds) public onlyOwner{
        upKeepIds=_upKeepIds;
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