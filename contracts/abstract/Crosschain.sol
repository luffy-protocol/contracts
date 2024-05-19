// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

abstract contract Crosschain {
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.

    address public protocolContract;
    IRouterClient public ccipRouter;
    LinkTokenInterface private linkToken;
    uint256 public ccipGasLimit;

    constructor(address _router, address _link, address _protocolContract) 
    {
        ccipRouter=IRouterClient(_router);
        linkToken=LinkTokenInterface(_link);
        ccipGasLimit=200_000;
    }

    function setCCIPGasLimit(uint256 newGasLimit) public {
        ccipGasLimit=newGasLimit;
    }

    function _makeSquadAndPlaceBetETHCrosschain(uint64 _destinationSelector, address _player, uint256 _betAmountInUSD, uint256 _betAmountInWei, uint8 _token) internal returns(bytes32 messageId) {
          Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(protocolContract), 
            data: abi.encode(_player, _betAmountInUSD, _betAmountInWei, _token), 
            tokenAmounts: new Client.EVMTokenAmount[](0), 
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: ccipGasLimit})
            ),
            feeToken: address(0)
        });

        uint256 fees = ccipRouter.getFee(
            _destinationSelector,
            evm2AnyMessage
        );

        if (fees > msg.value)
            revert NotEnoughBalance(msg.value, fees);

        messageId = ccipRouter.ccipSend{value: msg.value}(_destinationSelector, evm2AnyMessage);

        return messageId;
    }


}