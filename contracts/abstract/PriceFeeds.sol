// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

abstract contract PriceFeeds {
    
    AggregatorV3Interface public immutable ETH_USD_PRICE_FEED;
    AggregatorV3Interface public immutable LINK_USD_PRICE_FEED;

    constructor(AggregatorV3Interface _ethUsdPriceFeed, AggregatorV3Interface _linkUsdPriceFeed){
        ETH_USD_PRICE_FEED=_ethUsdPriceFeed;
        LINK_USD_PRICE_FEED=_linkUsdPriceFeed;
    }

    function getValueInUSD(uint256 amountInWei, uint8 _token) public view returns(uint256)
    {
        AggregatorV3Interface _priceFeed = _token==0 ? ETH_USD_PRICE_FEED : LINK_USD_PRICE_FEED;
        (, int price, , ,) = _priceFeed.latestRoundData();
        return (amountInWei*uint256(price))/10**18;
    }
}