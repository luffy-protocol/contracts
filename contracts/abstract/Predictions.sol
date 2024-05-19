// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "./PriceFeeds.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error InvalidBetToken(address token);
error SelectSquadDisabled(uint256 gameId);
error InsufficientBetAmount(address sender, address token, uint256 betInUSD, uint256 betInWei);
error InsufficientAllowance(address sender, address token, uint256 amountInWei);

abstract contract Predictions is ConfirmedOwner, PriceFeeds{

    uint256 public betAmount = 5 * 10 ** 8;
    mapping(uint256=>mapping(address=>bytes32)) public gameToSquadHash;
    mapping(uint256=>string) public playerIdRemappings;
    mapping(address=>bool) public whitelistedBetTokens;

    modifier isBetTokenWhitelisted(uint8 _token){
        address _betToken=address(priceFeeds[_token]);
        if(!whitelistedBetTokens[_betToken]) revert InvalidBetToken(_betToken);
        _;
    }

    event NewTokensWhitelisted(address[] betTokens);

    function whitelistBetTokens(address[] memory _betTokens) public onlyOwner {
        for(uint256 i=0; i<_betTokens.length; i++){
            whitelistedBetTokens[_betTokens[i]] = true;
        }
        emit NewTokensWhitelisted(_betTokens);
    }

    function makeSquadAndPlaceBetETH(uint256 _gameId, bytes32 _squadHash) public payable{
        if(bytes(playerIdRemappings[_gameId]).length>0) revert SelectSquadDisabled(_gameId);

        uint256 betAmountInUSD=getValueInUSD(msg.value,0);
        if(betAmountInUSD < betAmount) revert InsufficientBetAmount(msg.sender, address(0), betAmountInUSD, msg.value);
        
        _makeSquad(_gameId, _squadHash, address(0));
    }

    function makeSquadAndPlaceBetToken(uint256 _gameId, bytes32 _squadHash, uint8 _token, uint256 betAmountInWei) isBetTokenWhitelisted(_token) public {
        if(bytes(playerIdRemappings[_gameId]).length>0) revert SelectSquadDisabled(_gameId);

        address betToken=address(priceFeeds[_token]);
        if(IERC20(betToken).allowance(msg.sender, address(this)) < betAmountInWei) revert InsufficientAllowance(msg.sender, _token, betAmountInWei);

        uint256 betAmountInUSD=getValueInUSD(betAmountInWei, _token);
        if(betAmountInUSD < betAmount) revert InsufficientBetAmount(msg.sender, betToken, betAmountInUSD, betAmountInWei);

        IERC20(betToken).transferFrom(msg.sender, address(this), betAmountInWei);
        _makeSquad(_gameId, _squadHash, betToken);
    }

    function  _makeSquad(uint256 _gameId, bytes32 _squadHash, address token) internal {
        gameToSquadHash[_gameId][msg.sender] = _squadHash;
        emit Events.BetPlaced(_gameId, _squadHash, msg.sender, token);
    }

}