// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOrderBlock {
     event OrderCreated (
        uint128 marketId,
        uint128 price,
        uint128 amount,
        uint48 createdAt,
        uint8 side,
        uint8 typee
    );

    event OrderChanged (
        uint128 marketId,
        uint128 orderId,
        uint128 amount,
        uint8 typee
    );

    event OrderCanceled (
        uint128 marketId,
        uint128 orderId
    );

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

     struct OrderData {
        uint128 marketId;
        orderSide side;
        uint128 amount;
        address creator;
        uint128 slippage;

        uint128[] marketOrders;
        uint128[] prices;
        uint128[] amounts;
        address tokenAddress;
        address tokenAddressSecond;
        uint128 bestPrice;
        uint128 bestPriceOpposite;
    }
}