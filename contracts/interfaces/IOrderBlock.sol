// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOrderBlock {
    enum orderType {
        LIMIT, STOP, MARKET, EXECUTED, CANCELED, FAILED
    }

    enum orderSide {
        BUY, SELL
    }

    struct User {
        uint128[] orders;
    }

    struct Market {
        address base;
        address quote;
        uint128[] buyLimitOrders;
        uint128[] sellLimitOrders;
        uint128[] buyStopOrders;
        uint128[] sellStopOrders;
    }

    struct Order {
        address creator;
        uint128 marketId;
        uint128 price;
        uint128 amountTotal;
        uint128 amount;
        uint128 slippage;
        uint48 createdAt;
        uint8 side;
        uint8 typee;
    }

    function createMarket(address _base, address _quote) external;
    function createOrder(uint128 _marketId, uint128 _price, uint128 _amount, orderSide _side, orderType _type, uint128 _slippage) external payable;
    function cancelOrder(uint128 _marketId, uint128 _orderId) external;
    function getPairs() external view returns(string[] memory bases, string[] memory quotes, address[] memory basesAddr, address[] memory quotesAddr);
    function getPrice(uint128 _marketId) external view returns(uint128);
    function getMarketOrders(uint _marketId, orderSide _side, orderType _type) external view returns(Order[] memory, uint128[] memory);
    function getUserOrders(address _user) external view returns(Order[] memory, uint128[] memory);
}