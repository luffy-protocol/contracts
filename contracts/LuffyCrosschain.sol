

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./abstract/Predictions.sol";    

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

error NotEnoughCrosschainFee(uint256 balance, uint256 fee);

contract LuffyCrosschain is Predictions{

    uint64 public constant DESTINATION_CHAIN_SELECTOR=14767482510784806043; // AvalancheFuji Chain Selector
    address public protocolAddress;

    struct ConstructorParams{
        address protocolAddress;
        address ccipRouter;
        address USDC_TOKEN;
        address LINK_TOKEN;
        address vrfWrapper;
        AggregatorV3Interface[2] priceFeedAddresses;
    }

    constructor(ConstructorParams memory _params) Predictions(_params.ccipRouter, _params.USDC_TOKEN, _params.LINK_TOKEN, _params.vrfWrapper, _params.priceFeedAddresses) ConfirmedOwner(msg.sender){
        protocolAddress=_params.protocolAddress;
    }

    event CrosschainMessageSent(bytes32 messageId);

    // function makeSquadAndPlaceBetETH(uint256 _gameId, bytes32 _squadHash) public payable override returns(uint256){
    //     // uint256 _amountSpent=super.makeSquadAndPlaceBetETH(_gameId, _squadHash);
    //     // bytes memory _data=abi.encode(_gameId, msg.sender, _squadHash);
    //     // bytes32 _messageId = _sendMessagePayNative(msg.value - _amountSpent, _data);
    //     // emit CrosschainMessageSent(_messageId);
    //     // return 0;
    // }

    // function makeSquadAndPlaceBetLINK(uint256 _gameId, bytes32 _squadHash, uint256 _betAmountInWei) public payable override returns(uint256){
    //     // uint256 _amountSpent=super.makeSquadAndPlaceBetLINK(_gameId, _squadHash, _betAmountInWei);
    //     // bytes memory _data=abi.encode(_gameId, msg.sender, _squadHash);
    //     // bytes32 _messageId = _sendMessagePayNative(msg.value - _amountSpent, _data);
    //     // emit CrosschainMessageSent(_messageId);
    //     // return 0;
    // }

    // function makeSquadAndPlaceBetUSDC(uint256 _gameId, bytes32 _squadHash, uint256 _betAmountInWei) public payable override{
    //     // super.makeSquadAndPlaceBetUSDC(_gameId, _squadHash, _betAmountInWei);
    //     // bytes memory _data=abi.encode(_gameId, msg.sender, _squadHash);
    //     // bytes32 _messageId = _sendMessagePayNative(msg.value, _data);
    //     // emit CrosschainMessageSent(_messageId);
    // }


    function _sendMessagePayNative(uint256 _fee, bytes memory _data) internal returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_data);
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(DESTINATION_CHAIN_SELECTOR, evm2AnyMessage);

        if (fees > _fee)
            revert NotEnoughCrosschainFee(_fee, fees);

        IERC20(USDC_TOKEN).approve(address(router), _fee);

        messageId = router.ccipSend{value: fees}(
            DESTINATION_CHAIN_SELECTOR,
            evm2AnyMessage
        );

        return messageId;
    }

    function _buildCCIPMessage(
        bytes memory _data
    ) private view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: USDC_TOKEN,
            amount: BET_AMOUNT_IN_WEI
        });
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(protocolAddress),
                data: _data, 
                tokenAmounts: tokenAmounts, 
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: 300_000})
                ),
                feeToken: address(0)
            });
    }

    function setProtocolAddress(address _protocolAddress) external onlyOwner{
        protocolAddress=_protocolAddress;
    }

    function getCrosschainFee(uint64 destinationSelector, uint256 _gameId, bytes32 squadHash) external returns(uint256){
        IRouterClient router = IRouterClient(this.getRouter());
        bytes memory _data=abi.encode(_gameId, msg.sender, squadHash);
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_data);
        return router.getFee(DESTINATION_CHAIN_SELECTOR, evm2AnyMessage);
    }


}