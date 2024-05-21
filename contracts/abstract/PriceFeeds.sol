// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

abstract contract PriceFeeds {
    
    AggregatorV3Interface public ETH_USD_PRICE_FEED=AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
    AggregatorV3Interface public LINK_USD_PRICE_FEED=AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);


    function getValueInUSD(uint256 amountInWei, uint8 _token) public view returns(uint256)
    {
        AggregatorV3Interface _priceFeed = _token==0?ETH_USD_PRICE_FEED:LINK_USD_PRICE_FEED;
        (, int price, , ,) = _priceFeed.latestRoundData();
        return (amountInWei*uint256(price))/10**18;
    }
}