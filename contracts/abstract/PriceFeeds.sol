// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

abstract contract PriceFeeds {
    
    AggregatorV3Interface[3] public priceFeeds;

    constructor(AggregatorV3Interface[3] memory _priceFeedAddreses)
    {
        priceFeeds=_priceFeedAddreses;
    }

    function getValueInUSD(uint256 amountInWei, uint8 _token) public view returns(uint256)
    {
        (, int price, , ,) = priceFeeds[_token].latestRoundData();
        return (amountInWei*uint256(price))/10**18;
    }

}