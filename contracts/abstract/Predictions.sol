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

    uint256 public betAmount = 5 * 10 ** 8;
    mapping(uint256=>mapping(address=>bytes32)) public gameToSquadHash;
    mapping(uint256=>string) public playerIdRemappings;
    mapping(address=>bool) public whitelistedBetTokens;
    mapping(uint64=>address) public crosschainAddresses;


    constructor(address _ccipRouter, AggregatorV3Interface[3] memory _priceFeeds) CCIPReceiver(_ccipRouter) PriceFeeds(_priceFeeds) ConfirmedOwner(msg.sender){}


    modifier isBetTokenWhitelisted(uint8 _token){
        address _betToken=address(priceFeeds[_token]);
        if(!whitelistedBetTokens[_betToken]) revert InvalidBetToken(_betToken);
        _;
    }

    modifier onlyAllowlisted(uint64 _selector, address _caller){
        if(crosschainAddresses[_selector]!=_caller) revert InvalidCrosschainCaller(_caller);
        _;
    }

    event NewTokensWhitelisted(address[] betTokens);
    event BetPlaced(uint256 gameId, bytes32 squadHash, address caller, uint256 amount);
    event CrosschainAddressesSet(uint64[] destinationSelectors, address[] destinationAddresses); 
    event CrosschainReceived(bytes32 messageId);
    
    function whitelistBetTokens(address[] memory _betTokens) public  onlyOwner{
        for(uint256 i=0; i<_betTokens.length; i++){
            whitelistedBetTokens[_betTokens[i]] = true;
        }
        emit NewTokensWhitelisted(_betTokens);
    }

    function setCrosschainAddresses(uint64[] memory _destinationSelectors, address[] memory _destinationAddresses) public onlyOwner {
         for(uint256 i=0; i<_destinationSelectors.length; i++) crosschainAddresses[_destinationSelectors[i]] = _destinationAddresses[i];
        emit CrosschainAddressesSet(_destinationSelectors, _destinationAddresses);
    }

    function makeSquadAndPlaceBetETH(uint256 _gameId, bytes32 _squadHash) public payable{
        if(bytes(playerIdRemappings[_gameId]).length>0) revert SelectSquadDisabled(_gameId);

        uint256 betAmountInUSD=getValueInUSD(msg.value,0);
        if(betAmountInUSD < betAmount) revert InsufficientBetAmount(msg.sender, address(0), betAmountInUSD, msg.value);
        
        _makeSquad(_gameId, _squadHash, msg.sender, msg.value);
    }

    function makeSquadAndPlaceBetToken(uint256 _gameId, bytes32 _squadHash, uint8 _token, uint256 betAmountInWei) isBetTokenWhitelisted(_token) public {
        if(bytes(playerIdRemappings[_gameId]).length>0) revert SelectSquadDisabled(_gameId);

        address betToken=address(priceFeeds[_token]);
        if(IERC20(betToken).allowance(msg.sender, address(this)) < betAmountInWei) revert InsufficientAllowance(msg.sender, betToken, betAmountInWei);

        uint256 betAmountInUSD=getValueInUSD(betAmountInWei, _token);
        if(betAmountInUSD < betAmount) revert InsufficientBetAmount(msg.sender, betToken, betAmountInUSD, betAmountInWei);

        IERC20(betToken).transferFrom(msg.sender, address(this), betAmountInWei);
        _makeSquad(_gameId, _squadHash, msg.sender, betAmountInWei);
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
        _makeSquad(gameId, squadHash, player, any2EvmMessage.destTokenAmounts[0].amount);
        emit CrosschainReceived(any2EvmMessage.messageId);
    }

    function _makeSquad(uint256 _gameId, bytes32 _squadHash, address player, uint256 amount) internal {
        gameToSquadHash[_gameId][player] = _squadHash;
        emit BetPlaced(_gameId, _squadHash, player, amount);
    }

}