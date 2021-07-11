// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interfaces/IOrderBlock.sol";
import "./libraries/Utils.sol";
import "./libraries/PriorityList.sol";

contract OrderBlock is IOrderBlock
{   
    using SafeCast for uint;
    using PriorityList for Data[];

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    uint64 freeOrderId = 1;
    uint64 freeMarketId = 1;
    mapping(uint64 => Market) markets;
    mapping(uint64 => Order) orders;
    mapping(address => User) users;
    mapping(uint256 => bool) pairs;

    /**
    EXTERNAL FUNCTIONS
    */

    function createMarket(IERC20 _base, IERC20 _quote) external override
    {
        //verify user input
        require(_base != _quote, "SAME_TOKENS");
        require(address(_base) != address(0));

        //check if exists
        uint256 hashed = uint256(
            keccak256(abi.encodePacked(
                _base > _quote ? _base : _quote, 
                _base > _quote ? _quote : _base)
            )
        );
        require(!pairs[hashed], "PAIR_EXISTS");
        pairs[hashed] = true;

        //create market
        uint64 marketId = freeMarketId;
        markets[marketId].base = _base;
        markets[marketId].quote = _quote;
        freeMarketId++;

        //init priority lists
        markets[marketId].buyLimitOrders.init(64);
        markets[marketId].sellLimitOrders.init(64);
        markets[marketId].buyStopOrders.init(64);
        markets[marketId].sellStopOrders.init(64);
    }

    function createOrder(
        uint64 _marketId, 
        uint128 _price, 
        uint128 _amount, 
        orderSide _side, 
        orderType _type, 
        uint128 _slippage) external override payable lock
    {
        //verify user input
        Market storage market = markets[_marketId];
        require(_marketId < freeMarketId && freeMarketId != 0, "INVALID_MARKET");
        uint128 nearestBuyLimit = getNearestLimitOrder(_marketId, orderSide.BUY);
        uint128 nearestSellLimit = getNearestLimitOrder(_marketId, orderSide.SELL);
        IERC20 token = _side == orderSide.BUY ? market.quote : market.base;
        Utils.verifyOrderInput(
            _price,
            _amount,
            _side,
            _type, 
            _slippage, 
            nearestBuyLimit,
            nearestSellLimit,
            token,
            IERC20Metadata(address(token)).decimals()
        );
        if (_type == orderType.MARKET) {
            _price = (uint(nearestBuyLimit + nearestSellLimit) / 2).toUint128();
        }
        
        uint64 _orderId = freeOrderId;
        freeOrderId++;
        Order memory order = Order(
            _marketId,
            _price,
            uint48(block.timestamp), 
            _side, 
            _type,
            _amount,
            _slippage,
            msg.sender
        );

        //interact with the market
        if (_type == orderType.MARKET) {
            //market order
            Data[] storage limitOrders = _side == orderSide.BUY ? 
                markets[_marketId].sellLimitOrders : 
                markets[_marketId].buyLimitOrders;
            _marketOrder(order, limitOrders, token);

        } else {
            //limit or stop order
            Data[] storage marketOrders = _side == orderSide.BUY ? 
                (_type == orderType.STOP ? market.buyStopOrders : market.buyLimitOrders) : 
                (_type == orderType.STOP ? market.sellStopOrders : market.sellLimitOrders);

            //create order
            orders[_orderId] = order;
            users[msg.sender].orders.push(_orderId);
            marketOrders.insert(_orderId);
        }
        
        emit OrderCreated(
            _marketId, 
            _price,
            _amount,
            _side, 
            _type,
            _orderId, 
            uint48(block.timestamp)
        );
    }
	
    function cancelOrder(uint64 _orderId) external override lock
    {
        //verify user input
        require(_orderId < freeOrderId && _orderId != 0, "INVALID_ORDER");
        Order storage order = orders[_orderId];
        require(order.creator == msg.sender, "INVALID_SENDER");
        orderType typee = order.typee;
        require(typee == orderType.LIMIT || typee == orderType.STOP, "INVALID_TYPE");

        //remove order from market if it's on top
        uint64 marketId = order.marketId;
        orderSide side = order.side;
        Market storage market = markets[marketId];
        Data[] storage marketOrders = side == orderSide.BUY ? 
            (typee == orderType.STOP ? market.buyStopOrders : market.buyLimitOrders) : 
            (typee == orderType.STOP ? market.sellStopOrders : market.sellLimitOrders);
        (uint64 top, ) = marketOrders.getFirst();
        if (top == _orderId) {
            marketOrders.removeFirst();
        }

        //send tokens back
        IERC20 token = order.side == orderSide.BUY ? market.quote : market.base;
        Utils.transfer(token, address(this), msg.sender, order.amount);

        //cancel order
        order.typee = orderType.CANCELED;
        emit OrderCanceled(marketId, _orderId);
    }



    /**
    INTERNAL IMPLEMENTATION
    */

    //priority list calls this function to compare prices
    function compare(uint64 orderId1, uint64 orderId2) external view override returns (bool) 
    {
        orderSide side = orders[orderId1].side;
        orderType typee = orders[orderId1].typee;
        uint128 price1 = orders[orderId1].price;
        uint128 price2 = orders[orderId2].price;

        if (typee == orderType.CANCELED) return true;

        if (price1 == price2) {
            uint48 createdAt1 = orders[orderId1].createdAt;
            uint48 createdAt2 = orders[orderId2].createdAt;
            return createdAt2 >= createdAt1;
        } else {
            return typee == orderType.LIMIT ?
                (side == orderSide.BUY ? price1 > price2 : price1 < price2) :
                (side == orderSide.BUY ? price2 > price1 : price2 < price1);
        }
    }

    function _buildOrderQueue(Order memory marketOrder, Data[] storage limitOrders, uint8 baseDecimals) private returns (OrderQueue[] memory) 
    {
        OrderQueue[] memory orderQueue = new OrderQueue[](100);

        uint i;
        uint64 removeIndex;
        (uint64 matchedOrderId, uint64 index) = limitOrders.getFirst();
        require(matchedOrderId > 0, "NOT_FILLABLE_1");

        while (marketOrder.amount > 0 && i < 100) {
            uint128 orderPrice = orders[matchedOrderId].price;
            if (marketOrder.slippage > 0) {
                require(marketOrder.side == orderSide.BUY ? orderPrice <= marketOrder.slippage : orderPrice >= marketOrder.slippage, "PRICE_SLIPPAGE");
            }
            uint128 orderAmount = orders[matchedOrderId].amount;
            uint128 orderAmountConverted = Utils.convertOrderAmount(marketOrder.side, orderAmount, orderPrice, baseDecimals);
            uint128 amountIn;
            uint128 amountOut;

            if (orderAmountConverted > marketOrder.amount) {
                amountIn = marketOrder.amount;
                amountOut = Utils.convertOrderAmount(
                    marketOrder.side == orderSide.BUY ? orderSide.SELL : orderSide.BUY, 
                    marketOrder.amount, 
                    orderPrice, 
                    baseDecimals
                );
                require(amountOut > 0, "INVALID_AMOUNT");
                marketOrder.amount = 0;
            } else {
                amountIn = orderAmountConverted;
                amountOut = orderAmount;
                marketOrder.amount -= orderAmountConverted;
                do {
                    removeIndex = index;
                    (matchedOrderId, index) = limitOrders.getByIndex(index);
                    if (marketOrder.amount > 0) {
                        require(matchedOrderId > 0, "NOT_FILLABLE_2");
                    }
                } while(orders[matchedOrderId].typee != orderType.LIMIT);
            }
            orderAmount -= amountOut;

            orderQueue[i] = OrderQueue(
                matchedOrderId,
                orderAmount == 0,
                amountIn,
                amountOut,
                marketOrder.creator,
                orders[matchedOrderId].creator
            );

            i++;
        }
        
        require(marketOrder.amount == 0, "NOT_FILLABLE_3");
        if (removeIndex > 0) limitOrders.removeByIndex(removeIndex);
        return orderQueue;
    }

    function _marketOrder(Order memory marketOrder, Data[] storage limitOrders, IERC20 token) private
    {
        IERC20 tokenOpposite = marketOrder.side == orderSide.BUY ? 
            markets[marketOrder.marketId].base : 
            markets[marketOrder.marketId].quote;
        uint8 baseDecimals = IERC20Metadata(address(token)).decimals();
        OrderQueue[] memory orderQueue = _buildOrderQueue(marketOrder, limitOrders, baseDecimals);

        for (uint256 i = 0; i < orderQueue.length; i++) {
            uint64 orderId = orderQueue[i].orderId;
            if (orderId == 0) break;

            Utils.transfer(token, orderQueue[i].sender, orderQueue[i].creator, orderQueue[i].amountIn);
            Utils.transfer(tokenOpposite, address(this), orderQueue[i].sender, orderQueue[i].amountOut);

            if (orderQueue[i].filled) {
                emit OrderChanged(
                    marketOrder.marketId, 
                    orderId, 
                    0, 
                    orderType.EXECUTED
                );
                orders[orderId].typee = orderType.EXECUTED;
            } else {
                uint128 amountLeft = orders[orderId].amount - orderQueue[i].amountOut;
                emit OrderChanged(
                    marketOrder.marketId, 
                    orderId, 
                    amountLeft,
                    orderType.LIMIT
                );
                orders[orderId].amount = amountLeft;
            }
        }
    }

    /**
    VIEW FUNCTIONS
    */

    function getNearestLimitOrder(uint64 _marketId, orderSide _side) public view returns (uint128) 
    {
        Market storage market = markets[_marketId];
        Data[] storage marketOrders = _side == orderSide.BUY ? market.buyLimitOrders : market.sellLimitOrders;
        (uint64 orderId, ) = marketOrders.getFirst();
        return orders[orderId].price;
    }

    function getPairs(uint64 page) external override view returns(string[] memory bases, string[] memory quotes, IERC20[] memory basesAddr, IERC20[] memory quotesAddr)
    {
        uint64 marketId = freeMarketId;
        uint64 count = 100;
        bases = new string[](count);
        quotes = new string[](count);
        basesAddr = new IERC20[](count);
        quotesAddr = new IERC20[](count);
        for (uint64 i = (page * count); i < (page * count + count); i++) {
            if (i + 1 >= marketId) break;
            IERC20 base = markets[i + 1].base;
            IERC20 quote = markets[i + 1].quote;
            bases[i] = IERC20Metadata(address(base)).symbol();
            quotes[i] = IERC20Metadata(address(quote)).symbol();
            basesAddr[i] = base;
            quotesAddr[i] = quote;
        }
    }
	
    function getPrice(uint64 _marketId) external override view returns (uint128) 
    {
        uint256 nearestBuyLimit = getNearestLimitOrder(_marketId, orderSide.BUY);
        uint256 nearestSellLimit = getNearestLimitOrder(_marketId, orderSide.SELL);
        if (nearestBuyLimit == 0 || nearestSellLimit == 0) return 0;
        return ((nearestBuyLimit + nearestSellLimit) / 2).toUint128();
    }

    //needs to be paginated too
    function getMarketOrders(uint64 _marketId, orderSide _side, orderType _type) external override view returns (Order[] memory, uint64[] memory) 
    {
        Market storage market = markets[_marketId];
        Data[] storage marketOrders = _side == orderSide.BUY ? 
            (_type == orderType.LIMIT ? market.buyLimitOrders : market.buyStopOrders) :
            (_type == orderType.LIMIT ? market.sellLimitOrders : market.sellStopOrders);
        return _getOrders(marketOrders.getAllValues());
    }

    function getUserOrders(address _user) external override view returns (Order[] memory, uint64[] memory) 
    {
        return _getOrders(users[_user].orders);
    }

    function _getOrders(uint64[] memory ids) private view returns (Order[] memory, uint64[] memory)
    {
        Order[] memory o = new Order[](ids.length);
        for (uint64 i = 0; i < ids.length; i++) {
            o[i] = orders[ids[i]];
        }
        return (o, ids);
    }
}