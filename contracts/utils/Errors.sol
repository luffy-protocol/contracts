// Errors.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

error NotOwner(address caller);
error NotMailbox(address caller);
error InvalidGameweek(uint256 gameId);
error SelectSquadDisabled(uint256 gameId);
error ZeroKnowledgeVerificationFailed();
error NotAllowedCaller(address caller, address owner);
error UnexpectedRequestID(bytes32 requestId);
error ResultsNotPublished(uint256 gameId);
error InvalidBetToken(address betToken);
error InsufficientBetAmount(address owner, address token, uint256 betAmountInUSD, uint256 betAmountInWei);
error InsufficientAllowance(address owner, uint8 tokenId, uint256 betAmountInWei);
error InvalidAutomationCaller(address caller);