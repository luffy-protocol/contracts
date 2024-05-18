// Events.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
    
event GamePlayerIdRemappingSet(uint256 gameId, string remapping);
event PlayersMetadataUpdated(uint256 playersMetadataLength, string[] playersMetadata);
event SquadRegistered(uint256 gameId, bytes32 squadHash, address registrant);
event PointsClaimed(uint256 gameId, address claimer, uint256 totalPoints);
event ResultsFetchInitiated(uint256 gameId, bytes32 requestId);
event ResultsPublished(uint256 gameId, bytes32 pointsMerkleRoot, string gameResults);
event ResultsFetchFailed(uint256 gameId, bytes32 requestId, bytes error);
event ClaimPointsDisabled(uint256 gameId);
event NewTokensWhitelisted(address[] tokens);
event BetAmountSet(uint256 amount);
event BetPlaced(uint256 gameId, bytes32 squadHash, address player, address token);