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
        uint64[] orders;
    }

    struct Market {
        address base;
        address quote;
        uint64[] buyLimitOrders;
        uint64[] sellLimitOrders;
        uint64[] buyStopOrders;
        uint64[] sellStopOrders;
    }

    struct Order {
        uint64 marketId;
        address creator;
        uint128 amount;
        uint128 slippage;
        uint128 price;
        uint48 createdAt;
        orderSide side;
        orderType typee;
        uint128 amountTotal;
    }

    function createMarket(address _base, address _quote) external;
    function createOrder(uint64 _marketId, uint128 _price, uint128 _amount, orderSide _side, orderType _type, uint128 _slippage) external payable;
    function cancelOrder(uint64 _orderId) external;
    function getPairs(uint64 page) external view returns(string[] memory bases, string[] memory quotes, address[] memory basesAddr, address[] memory quotesAddr);
    function getPrice(uint64 _marketId) external view returns(uint128);
    function getMarketOrders(uint64 _marketId, orderSide _side, orderType _type) external view returns(Order[] memory, uint64[] memory);
    function getUserOrders(address _user) external view returns(Order[] memory, uint64[] memory);
}