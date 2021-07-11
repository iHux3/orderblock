// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPriorityList.sol";

interface IOrderBlock is IPriorityList {
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
        IERC20 base;
        IERC20 quote;
        Data[] buyLimitOrders;
        Data[] sellLimitOrders;
        Data[] buyStopOrders;
        Data[] sellStopOrders;
    }

    struct Order {
        uint64 marketId;
        uint128 price;
        uint48 createdAt;
        orderSide side;
        orderType typee;
        uint128 amount;
        uint128 slippage;
        address creator;
    }

    struct OrderQueue {
        uint64 orderId;
        bool filled;
        uint128 amountIn;
        uint128 amountOut;
        address sender;
        address creator;
    }

    event OrderCreated (
        uint64 marketId,
        uint128 price,
        uint128 amount,
        orderSide side,
        orderType typee,
        uint64 orderId,
        uint48 createdAt
    );

    event OrderChanged (
        uint64 marketId,
        uint64 orderId,
        uint128 amount,
        orderType typee
    );

    event OrderCanceled (
        uint64 marketId,
        uint64 orderId
    );

    function createMarket(IERC20 _base, IERC20 _quote) external;
    function createOrder(uint64 _marketId, uint128 _price, uint128 _amount, orderSide _side, orderType _type, uint128 _slippage) external payable;
    function cancelOrder(uint64 _orderId) external;
    function getPairs(uint64 page) external view returns(string[] memory bases, string[] memory quotes, IERC20[] memory basesAddr, IERC20[] memory quotesAddr);
    function getPrice(uint64 _marketId) external view returns(uint128);
    function getMarketOrders(uint64 _marketId, orderSide _side, orderType _type) external view returns(Order[] memory, uint64[] memory);
    function getUserOrders(address _user) external view returns(Order[] memory, uint64[] memory);
}