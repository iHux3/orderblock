// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interfaces/IOrderBlock.sol";
import "./libraries/Utils.sol";
import "hardhat/console.sol";

contract OrderBlock is IOrderBlock
{
    using SafeMath for uint;
    using SafeCast for uint;

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint constant STOPORDER_FEE = 0;

    uint128 orderId = 1;
    uint128 marketId = 1;
    mapping(uint => Market) markets;
    mapping(uint => Order) orders;
    mapping(address => User) users;
    mapping(address => address[]) pairs;

    function createMarket(address _base, address _quote) external 
    {
        //verify user input
        require(_base != _quote, "SAME_TOKENS");
        _checkIfExists(_base, _quote);
        _checkIfExists(_quote, _base);

        //basic verification address is a token
        if (_base != ETH) IERC20(_base).totalSupply();
        if (_quote != ETH) IERC20(_quote).totalSupply();

        //create market
        markets[marketId].base = _base;
        markets[marketId].quote = _quote;
        marketId++;
        pairs[_base].push(_quote);
    }

    function _checkIfExists(address _base, address _quote) private view
    {
        if (pairs[_base].length != 0) {
            address[] memory copy = pairs[_base];
            for (uint i = 0; i < copy.length; i++) {
                if (copy[i] == _quote) revert("PAIR_EXISTS");
            }
        }
    }

    function createOrder(uint128 _marketId, uint128 _price, uint128 _amount, orderSide _side, orderType _type, uint128 _slippage) external payable
    {
        //verify user input
        Market storage market = markets[_marketId];
        require(_marketId < marketId && marketId != 0, "INVALID_MARKET");
        uint128 nearestBuyLimit = Utils.getNearestLimit(market, orderSide.BUY, orders);
        uint128 nearestSellLimit = Utils.getNearestLimit(market, orderSide.SELL, orders);
        address tokenAddress = _side == orderSide.BUY ? market.quote : market.base;
        Utils.verifyOrderInput(
            _price,
            _amount,
            _side,
            _type, 
            _slippage, 
            nearestBuyLimit,
            nearestSellLimit,
            tokenAddress
        );


        //core
        if (_type != orderType.MARKET) {
            //market or stop order
            uint128[] storage marketOrdersStorage = _side == orderSide.BUY ? 
                (_type == orderType.STOP ? market.buyStopOrders : market.buyLimitOrders) : 
                (_type == orderType.STOP ? market.sellStopOrders : market.sellLimitOrders);
            uint128[] memory marketOrders = marketOrdersStorage;
            bool created = false;
            for (uint i = 0; i < marketOrders.length; i++) {
                if (marketOrders[i] == 0) {
                    marketOrders[i] = orderId;
                    marketOrdersStorage[i] = orderId;
                    created = true;
                    break;
                }
            }
            
            Utils.ordersPop(marketOrders, marketOrdersStorage);
            if (!created) marketOrdersStorage.push(orderId);
        } else {
            //market order
            uint128[] storage marketOrdersStorage = _side == orderSide.BUY ? market.sellLimitOrders : market.buyLimitOrders;
            uint128[] memory marketOrders = marketOrdersStorage;
            require(marketOrders.length > 0, "NO_LIMIT_ORDERS");

            OrderData memory data = OrderData(
                _marketId,
                _side,
                _amount,
                msg.sender,
                _slippage,
                marketOrders,
                new uint128[](marketOrders.length),
                new uint128[](marketOrders.length),
                tokenAddress,
                _side == orderSide.BUY ? market.base : market.quote,
                0,
                0
            );

            for (uint i = 0; i < data.marketOrders.length; i++) {
                data.prices[i] = orders[marketOrders[i]].price;
                data.amounts[i] = orders[marketOrders[i]].amount;
            }
            data.bestPriceOpposite = Utils.getNearestLimit(market, data.side, orders);

            if (!Utils._isFillable(data)) revert("NOT_FILLABLE");

            data.bestPrice = _marketOrder(data, marketOrdersStorage);
            _executeStopOrders(data, marketOrdersStorage);
            Utils.ordersPop(marketOrders, marketOrdersStorage);
        }

        //create order
        orders[orderId] = Order(msg.sender, _marketId, _price, _amount, _type == orderType.LIMIT ? _amount : 0, _slippage,
            uint48(block.timestamp), uint8(_side), uint8(_type));
        users[msg.sender].orders.push(orderId);
        orderId++;
        emit OrderCreated(_marketId, _price, _amount, uint48(block.timestamp), uint8(_side), uint8(_type));
    }

    function _executeStopOrders(OrderData memory data, uint128[] storage marketOrdersStorage) private 
    {
        Market storage market = markets[data.marketId];
        uint executedCount;
        uint128[] storage marketStopOrdersStorage = data.side == orderSide.BUY ? market.buyStopOrders : market.sellStopOrders;
        uint128[] memory marketStopOrders = marketStopOrdersStorage;
        for (uint i = 0; i < marketStopOrders.length; i++) {
            uint128 id = marketStopOrders[i];
            uint price = uint(data.bestPrice + data.bestPriceOpposite).div(2);
            if (id != 0) {
                Order storage o = orders[id];
                data.side = orderSide(o.side);
                if (data.bestPrice > 0 && data.bestPriceOpposite > 0 && (data.side == orderSide.BUY ? o.price <= price : o.price >= price)) {
                    data.amount = o.amountTotal;
                    data.creator = o.creator;
                    data.slippage = o.slippage;
                    if (Utils._isFillable(data)) {
                        data.bestPrice = _marketOrder(data, marketOrdersStorage);
                        executedCount++;
                    } else {
                        Utils.transfer(data.tokenAddress, address(this), data.creator, data.amount);
                        payable(data.creator).transfer(STOPORDER_FEE);
                        o.typee = uint8(orderType.FAILED);
                        emit OrderChanged(data.marketId, id, 0, uint8(orderType.FAILED));
                    }
                    marketStopOrders[i] = 0;
                    marketStopOrdersStorage[i] = 0;
                }
            }
        }

        //send fee to market order creator
        if (executedCount > 0) payable(msg.sender).transfer(STOPORDER_FEE * executedCount);

        Utils.ordersPop(marketStopOrders, marketStopOrdersStorage);
    }
    

    function _marketOrder(OrderData memory data, uint128[] storage marketOrdersStorage) private returns(uint128)
    {
        uint128 remainingAmount = data.amount;
        uint128 bestPrice;
        uint bestPriceIndex;
        bool findNext = false;

        while (remainingAmount > 0 || findNext) {
            //finding the best match
            bestPrice = 0;
            for (uint i = 0; i < data.marketOrders.length; i++) {
                uint128 id = data.marketOrders[i];
                if (id != 0) {
                    if (bestPrice == 0) {
                        bestPrice = data.prices[i];
                        bestPriceIndex = i;
                    } else {
                        if (data.side == orderSide.BUY ? data.prices[i] < bestPrice : data.prices[i] > bestPrice) {
                            bestPrice = data.prices[i];
                            bestPriceIndex = i;
                        } else if (data.prices[i] == bestPrice && bestPriceIndex != i) {
                            if (orders[id].createdAt < orders[data.marketOrders[bestPriceIndex]].createdAt) {
                                bestPriceIndex = i;
                            }
                        }
                    }
                }
            }
            
            if (findNext) return bestPrice;
            
            //transfering tokens
            uint128 bestId = data.marketOrders[bestPriceIndex];
            Order storage matchedOrder = orders[bestId];
            uint128 orderAmount = data.amounts[bestPriceIndex];

            uint128 orderAmountConverted = data.side == orderSide.BUY ?
                uint(orderAmount * bestPrice).div(1 ether).toUint128() :
                uint(orderAmount * 1 ether).div(bestPrice).toUint128();

            if (orderAmountConverted > remainingAmount) {
                //marketOrder creator sends
                Utils.transfer(data.tokenAddress, data.creator, matchedOrder.creator, remainingAmount);
                
                //matched creator sends
                uint128 amountToSend = data.side == orderSide.BUY ?
                    uint(remainingAmount * 1 ether).div(bestPrice).toUint128() :
                    uint(remainingAmount * bestPrice).div(1 ether).toUint128();
                Utils.transfer(data.tokenAddressSecond, address(this), data.creator, amountToSend);

                matchedOrder.amount -= amountToSend;
                data.amounts[bestPriceIndex] -= amountToSend;
                remainingAmount = 0;
                emit OrderChanged(data.marketId, bestId, orderAmount - amountToSend, uint8(orderType.LIMIT));
            } else {
                if (orderAmountConverted == remainingAmount) findNext = true;
                //marketOrder creator sends
                Utils.transfer(data.tokenAddress, msg.sender, matchedOrder.creator, orderAmountConverted);

                //matched creator sends
                Utils.transfer(data.tokenAddressSecond, address(this), data.creator, orderAmount);

                remainingAmount -= orderAmountConverted;
                matchedOrder.amount = 0;
                matchedOrder.typee = uint8(orderType.EXECUTED);
                data.marketOrders[bestPriceIndex] = 0;
                marketOrdersStorage[bestPriceIndex] = 0;
                emit OrderChanged(data.marketId, bestId, 0, uint8(orderType.EXECUTED));
            }
        }

        return bestPrice;
    }
	
    function cancelOrder(uint128 _marketId, uint128 _orderId) external 
    {
        //verify user input
        Order storage order = orders[_orderId];
        Market storage market = markets[_marketId];
        require(_orderId < orderId && _orderId != 0, "INVALID_ORDER");
        require(_marketId < marketId && _marketId != 0, "INVALID_MARKET");
        require(order.creator == msg.sender, "INVALID_SENDER");
        orderType typee = orderType(order.typee);
        require(typee == orderType.LIMIT || typee == orderType.STOP, "INVALID_TYPE");
        orderSide side = orderSide(order.side);

        //remove order from market ids
        uint128[] storage marketOrdersStorage = side == orderSide.BUY ? 
                (typee == orderType.STOP ? market.buyStopOrders : market.buyLimitOrders) : 
                (typee == orderType.STOP ? market.sellStopOrders : market.sellLimitOrders);
        uint128[] memory marketOrders = marketOrdersStorage;
        bool found = false;
        for (uint i = 0; i < marketOrders.length; i++) {
            if (_orderId == marketOrders[i]) {
                marketOrdersStorage[i] = 0;
                found = true;
                break;
            }
        }
        require(found, "ORDER_NOT_FOUND");

        //send tokens
        address tokenAddress = side == orderSide.BUY ? market.quote : market.base;
        Utils.transfer(tokenAddress, address(this), msg.sender, order.amount);
        if (typee == orderType.STOP) payable(msg.sender).transfer(STOPORDER_FEE);

        //cancel order
        order.typee = uint8(orderType.CANCELED);
        emit OrderCanceled(_marketId, _orderId);
    }



    function getPairs() public view returns(address[] memory bases, address[] memory quotes)
    {
        uint _marketId = marketId - 1;
        bases = new address[](_marketId);
        quotes = new address[](_marketId);
        for (uint i = 0; i < _marketId; i++) {
            bases[i] = markets[i + 1].base;
            quotes[i] = markets[i + 1].quote;
        }
    }
	
    function getPrice(uint128 _marketId) public view returns(uint128) 
    {
        Market storage market = markets[_marketId];
        return uint(Utils.getNearestLimit(market, orderSide.BUY, orders) + Utils.getNearestLimit(market, orderSide.SELL, orders)).div(2).toUint128();
    }

    function getMarketOrders(uint _marketId, orderSide _side, orderType _type) public view returns(Order[] memory, uint128[] memory) 
    {
        Market storage market = markets[_marketId];
        return getOrders(_side == orderSide.BUY ? 
            (_type == orderType.LIMIT ? market.buyLimitOrders : market.buyStopOrders) :
            (_type == orderType.LIMIT ? market.sellLimitOrders : market.sellStopOrders));
    }

    function getUserOrders(address _user) public view returns(Order[] memory, uint128[] memory) 
    {
        return getOrders(users[_user].orders);
    }

    function getOrders(uint128[] memory ids) private view returns(Order[] memory, uint128[] memory)
    {
        Order[] memory o = new Order[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            o[i] = orders[ids[i]];
        }
        return (o, ids);
    }
}