

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./abstract/Predictions.sol";    

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

error NotEnoughCrosschainFee(uint256 balance, uint256 fee);

contract LuffyCrosschain is Predictions{

    uint64 public constant DESTINATION_CHAIN_SELECTOR=14767482510784806043; // AvalancheFuji Chain Selector
    address public protocolAddress;

    mapping(address=>uint256) public valueBalance;


    constructor(address _protocolAddress, address _vrfWrapper, address _ccipRouter, address _usdcToken, address _linkToken, AggregatorV3Interface[2] memory _priceFeeds) Predictions( _vrfWrapper,  _ccipRouter,  _usdcToken,  _linkToken, _priceFeeds) ConfirmedOwner(msg.sender) {
        protocolAddress=_protocolAddress;
    }

    event CrosschainMessageSent(bytes32 messageId);

    function makeSquadAndPlaceBet(uint256 _gameId, bytes32 _squadHash, uint256 _amount, uint8 _token, uint8 _captain, uint8 _viceCaptain) external payable{
        uint256 _remainingValue=_makeSquadAndPlaceBet(_gameId, _squadHash, _amount, _token, _captain, _viceCaptain);
        bytes memory _data=abi.encode(_gameId, msg.sender, _squadHash, _token, _captain, _viceCaptain, false);
        _sendMessagePayNative(_remainingValue, _data);
    }

    function makeSquadAndPlaceBetRandom(uint256 _gameId, bytes32 _squadHash, uint256 _amount, uint8 _token) external payable{
        uint256 _remainingValue=_makeSquadAndPlaceBetRandom(_gameId, _squadHash, _amount, _token);
        valueBalance[msg.sender]=_remainingValue;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override{
        VrfTracker memory _game = vrfRequests[_requestId];
        uint256 _randomWord=_randomWords[0];
        gameToPrediction[_game.gameId][_game.player].captain = uint8(_randomWord % 11);
        _randomWord = _randomWord / 100;
        gameToPrediction[_game.gameId][_game.player].viceCaptain = uint8(_randomWord % 11);

        Prediction memory _prediction=gameToPrediction[_game.gameId][_game.player];

        emit BetPlaced(_game.gameId, _game.player, gameToPrediction[_game.gameId][_game.player]);
        
        bytes memory _data=abi.encode(_game.gameId, _game.player, block.timestamp, _prediction.squadHash, _prediction.token, _prediction.captain, _prediction.viceCaptain, true);

        _sendMessagePayNative(valueBalance[_game.player], _data);
        
    }


    function _sendMessagePayNative(uint256 _fee, bytes memory _data) internal returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_data);
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(DESTINATION_CHAIN_SELECTOR, evm2AnyMessage);

        if (fees > _fee)
            revert NotEnoughCrosschainFee(_fee, fees);

        IERC20(USDC_TOKEN).approve(address(router), _fee);

        messageId = router.ccipSend{value: _fee}(
            DESTINATION_CHAIN_SELECTOR,
            evm2AnyMessage
        );
        emit CrosschainMessageSent(messageId);
        return messageId;
    }

    function _buildCCIPMessage(
        bytes memory _data
    ) private view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: USDC_TOKEN,
            amount: BET_AMOUNT_IN_USDC
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
    
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
    {}

    function setProtocolAddress(address _protocolAddress) external onlyOwner{
        protocolAddress=_protocolAddress;
    }

    function getCrosschainFee(uint256 _gameId, bytes32 _squadHash, uint8 _token, uint8 _captain, uint8 _viceCaptain, bool _isRandom) external view returns(uint256){
        IRouterClient router = IRouterClient(this.getRouter());
        bytes memory _data=abi.encode(_gameId, msg.sender, _squadHash, _token, _captain, _viceCaptain, _isRandom);
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_data);
        return router.getFee(DESTINATION_CHAIN_SELECTOR, evm2AnyMessage);
    }


}