// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "./PriceFeeds.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

error InvalidBetToken(address token);
error SelectSquadDisabled(uint256 gameId);
error InsufficientBetAmount(address sender, address token, uint256 betInUSD, uint256 betInWei);
error InsufficientAllowance(address sender, address token, uint256 amountInWei);
error InvalidCrosschainCaller(address caller);

abstract contract Predictions is PriceFeeds, CCIPReceiver, ConfirmedOwner{

    uint256 public BET_AMOUNT_IN_WEI = 1 * 10 ** 15;
    mapping(uint256=>mapping(address=>bytes32)) public gameToSquadHash;
    mapping(uint256=>string) public playerIdRemappings;
    mapping(uint64=>address) public crosschainAddresses;

    address public usdcToken;
    address public linkToken;

    constructor(address _ccipRouter, address _usdcToken, address _linkToken, AggregatorV3Interface[2] memory _priceFeeds) CCIPReceiver(_ccipRouter) PriceFeeds(_priceFeeds) ConfirmedOwner(msg.sender){
        usdcToken=_usdcToken;
        linkToken=_linkToken;
    }

    modifier onlyAllowlisted(uint64 _selector, address _caller){
        if(crosschainAddresses[_selector]!=_caller) revert InvalidCrosschainCaller(_caller);
        _;
    }

    event BetPlaced(uint256 gameId, bytes32 squadHash, address caller, uint256 amount);
    event CrosschainAddressesSet(uint64[] destinationSelectors, address[] destinationAddresses); 
    event CrosschainReceived(bytes32 messageId);
    event BetAmountSet(uint256 amount);

    function setCrosschainAddresses(uint64[] memory _destinationSelectors, address[] memory _destinationAddresses) external onlyOwner {
         for(uint256 i=0; i<_destinationSelectors.length; i++) crosschainAddresses[_destinationSelectors[i]] = _destinationAddresses[i];
        emit CrosschainAddressesSet(_destinationSelectors, _destinationAddresses);
    }

    function makeSquadAndPlaceBetETH(uint256 _gameId, bytes32 _squadHash) public virtual payable returns(uint256) {
        if(bytes(playerIdRemappings[_gameId]).length>0) revert SelectSquadDisabled(_gameId);

        uint256 _betAmountInUSD=getValueInUSD(msg.value, 0);

        // TODO: Swap ETH to USDC
        if(_betAmountInUSD < BET_AMOUNT_IN_WEI / 10 ** 8) revert InsufficientBetAmount(msg.sender, address(0), _betAmountInUSD, msg.value);
        
        _makeSquad(_gameId, _squadHash, msg.sender, msg.value);
        // Return the total amount that was used for both the bet and the swap combined
        return msg.value;
    }


    function makeSquadAndPlaceBetLINK(uint256 _gameId, bytes32 _squadHash, uint256 _betAmountInWei) public virtual payable returns(uint256) {
        if(bytes(playerIdRemappings[_gameId]).length>0) revert SelectSquadDisabled(_gameId);

        if(IERC20(linkToken).allowance(msg.sender, address(this)) < _betAmountInWei) revert InsufficientAllowance(msg.sender, linkToken, _betAmountInWei);

        uint256 _betAmountInUSD=getValueInUSD(_betAmountInWei, 1);

        IERC20(linkToken).transferFrom(msg.sender, address(this), _betAmountInWei);

        // TODO: Swap LINK to USDC

        if(_betAmountInUSD < BET_AMOUNT_IN_WEI / 10 ** 8) revert InsufficientBetAmount(msg.sender, linkToken, _betAmountInUSD, _betAmountInWei);

        _makeSquad(_gameId, _squadHash, msg.sender, _betAmountInWei);
        // Return the total amount that was used for both the bet and the swap combined
        return _betAmountInWei;
    }

    function makeSquadAndPlaceBetUSDC(uint256 _gameId, bytes32 _squadHash, uint256 _betAmountInWei) public virtual payable {
        if(bytes(playerIdRemappings[_gameId]).length>0) revert SelectSquadDisabled(_gameId);

        if(IERC20(usdcToken).allowance(msg.sender, address(this)) < _betAmountInWei) revert InsufficientAllowance(msg.sender, usdcToken, _betAmountInWei);

        IERC20(usdcToken).transferFrom(msg.sender, address(this), _betAmountInWei);

        if(_betAmountInWei < BET_AMOUNT_IN_WEI) revert InsufficientBetAmount(msg.sender, usdcToken, _betAmountInWei, _betAmountInWei);

        _makeSquad(_gameId, _squadHash, msg.sender, _betAmountInWei);
    }


    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        ) 
    {
        (uint256 gameId, address player, bytes32 squadHash) = abi.decode(any2EvmMessage.data, (uint256, address, bytes32));
        if(any2EvmMessage.destTokenAmounts[0].amount < BET_AMOUNT_IN_WEI) revert InsufficientBetAmount(msg.sender, usdcToken, any2EvmMessage.destTokenAmounts[0].amount, any2EvmMessage.destTokenAmounts[0].amount);

        _makeSquad(gameId, squadHash, player, any2EvmMessage.destTokenAmounts[0].amount);
        emit CrosschainReceived(any2EvmMessage.messageId);
    }

    function _makeSquad(uint256 _gameId, bytes32 _squadHash, address player, uint256 amount) internal {
        gameToSquadHash[_gameId][player] = _squadHash;
        emit BetPlaced(_gameId, _squadHash, player, amount);
    }

    function setBetAmountInUSDC(uint256 _amount) external onlyOwner {
        BET_AMOUNT_IN_WEI = _amount;
        emit BetAmountSet(_amount);
    }

}