// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interfaces/IOrderBlock.sol";
import "./interfaces/IComparing.sol";
import "./libraries/Utils.sol";
import "./libraries/Heap.sol";

contract OrderBlock is IOrderBlock, IComparing
{   
    using SafeMath for uint;
    using SafeMath for uint64;
    using SafeCast for uint;
    using Heap for uint64[];

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    event OrderCreated (
        uint64 marketId,
        uint64 orderId,
        uint128 price,
        uint128 amount,
        uint48 createdAt,
        orderSide side,
        orderType typee
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

    uint64 freeOrderId = 1;
    uint64 freeMarketId = 1;
    mapping(uint => Market) markets;
    mapping(uint => Order) orders;
    mapping(address => User) users;
    mapping(uint256 => bool) pairs;



    /**
    EXTERNAL FUNCTIONS
    */

    function createMarket(address _base, address _quote) external override
    {
        //verify user input
        require(_base != _quote, "SAME_TOKENS");
        require(_base != address(0));

        //check if exists
        uint hashed = uint(keccak256(abi.encodePacked(_base, _quote)));
        require(!pairs[hashed], "PAIR_EXISTS");
        pairs[hashed] = true;

        //create market
        uint64 marketId = freeMarketId;
        markets[marketId].base = _base;
        markets[marketId].quote = _quote;
        freeMarketId.add(1);

        //init heaps
        markets[marketId].buyLimitOrders = Heap.init(64);
        markets[marketId].sellLimitOrders = Heap.init(64);
        markets[marketId].buyStopOrders = Heap.init(64);
        markets[marketId].sellStopOrders = Heap.init(64);
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

        //interact with the market
        if (_type != orderType.MARKET) {
            //limit or stop order
            uint64[] storage marketOrders = _side == orderSide.BUY ? 
                (_type == orderType.STOP ? market.buyStopOrders : market.buyLimitOrders) : 
                (_type == orderType.STOP ? market.sellStopOrders : market.sellLimitOrders);
            marketOrders.add(freeOrderId);
        } else {
            //market order
            _marketOrder(_marketId, _amount, _side, _slippage, tokenAddress);
            //_executeStopOrders(data, marketOrders);
        }

        //create order
        uint64 _orderId = freeOrderId;
        orders[_orderId] = Order(
            _marketId,
            msg.sender,
            _type == orderType.LIMIT ? _amount : 0, //remaining amount only for limit order
            _slippage,
            _price,
            uint48(block.timestamp), 
            _side, 
            _type,
            _amount
        );
        users[msg.sender].orders.push(_orderId);
        emit OrderCreated(_marketId, _orderId, _price, _amount, uint48(block.timestamp), _side, _type);
        freeOrderId.add(1);
    }
	
    function cancelOrder(uint64 _orderId) external override lock
    {
        //verify user input
        require(_orderId < freeOrderId && _orderId != 0, "INVALID_ORDER");
        Order storage order = orders[_orderId];
        require(order.creator == msg.sender, "INVALID_SENDER");
        orderType typee = order.typee;
        require(typee == orderType.LIMIT || typee == orderType.STOP, "INVALID_TYPE");

        //send tokens back
        uint64 marketId = order.marketId;
        Market storage market = markets[marketId];
        address tokenAddress = order.side == orderSide.BUY ? market.quote : market.base;
        Utils.transfer(tokenAddress, address(this), msg.sender, order.amount);

        //cancel order
        order.typee = orderType.CANCELED;
        emit OrderCanceled(marketId, _orderId);
    }



    /**
    INTERNAL IMPLEMENTATION
    */

    //heap calls this function to compare prices
    function compare(uint64 orderId1, uint64 orderId2) external view override returns (bool) {
        //return value1 > value2;
        orderSide side = orders[orderId1].side;
        orderType typee = orders[orderId1].typee;
        uint128 price1 = orders[orderId1].price;
        uint128 price2 = orders[orderId2].price;

        if (typee == orderType.CANCELED) return true;

        if (price1 == price2) {
            uint48 createdAt1 = orders[orderId1].createdAt;
            uint48 createdAt2 = orders[orderId2].createdAt;
            return createdAt2 > createdAt1;
        } else {
            return typee == orderType.LIMIT ?
                (side == orderSide.BUY ? price1 > price2 : price1 < price2) :
                (side == orderSide.BUY ? price2 > price1 : price2 < price1);
        }
    }

    function _marketOrder(uint64 _marketId, uint128 _amount, orderSide _side, uint128 _slippage, address tokenAddress) private
    {
        Market storage market = markets[_marketId];
        uint64[] storage marketOrders = _side == orderSide.BUY ? market.sellLimitOrders : market.buyLimitOrders;
        address tokenAddressSecond = _side == orderSide.BUY ? market.base : market.quote;
        uint128 remainingAmount = _amount;

        while (remainingAmount > 0) {
            //finding the best match
            (uint64 bestOrderId, uint128 bestPrice) = _matchOrder(marketOrders, _side, _slippage);

            Order storage matchedOrder = orders[bestOrderId];
            uint128 orderAmount = matchedOrder.amount;
            uint128 orderAmountConverted = _convertOrderAmount(_side, orderAmount, bestPrice);

            if (orderAmountConverted > remainingAmount) {
                //marketOrder creator sends
                Utils.transfer(tokenAddress, msg.sender, matchedOrder.creator, remainingAmount);
                
                //matched creator sends
                uint128 amountToSend = _convertOrderAmount(_side == orderSide.BUY ? orderSide.SELL : orderSide.BUY, remainingAmount, bestPrice);
                Utils.transfer(tokenAddressSecond, address(this), msg.sender, amountToSend);

                matchedOrder.amount -= amountToSend;
                remainingAmount = 0;
                emit OrderChanged(_marketId, bestOrderId, orderAmount - amountToSend, orderType.LIMIT);
            } else {
                //marketOrder creator sends
                Utils.transfer(tokenAddress, msg.sender, matchedOrder.creator, orderAmountConverted);

                //matched creator sends
                Utils.transfer(tokenAddressSecond, address(this), msg.sender, orderAmount);

                remainingAmount -= orderAmountConverted;
                matchedOrder.amount = 0;
                matchedOrder.typee = orderType.EXECUTED;
                marketOrders.removeTop();
                emit OrderChanged(_marketId, bestOrderId, 0, orderType.EXECUTED);
            }
        }
    }

    function _matchOrder(uint64[] storage marketOrders, orderSide _side, uint128 _slippage) private returns (uint64, uint128) {

        uint64 bestOrderId;
        uint128 bestPrice;
        uint maxIndex = marketOrders[0];
        uint i = 1;
        while (i < maxIndex) {
            uint64 top = marketOrders.getTop();
            if (orders[top].typee != orderType.CANCELED) {
                bestPrice = orders[top].price;
                if (_slippage > 0) {
                    require(_side == orderSide.BUY ? bestPrice <= _slippage : bestPrice >= _slippage, "PRICE_SLIPPAGE");
                }
                bestOrderId = top;
                break;
            } else {
                marketOrders.removeTop();
                maxIndex--;
            }
            i++;
        }
        require(bestOrderId != 0, "NOT_ENOUGH_ORDERS");
        return (bestOrderId, bestPrice);
    }


    /**
    VIEW FUNCTIONS
    */

    function _convertOrderAmount(orderSide _side, uint128 _amount, uint128 _price) private pure returns (uint128) {
        return _side == orderSide.BUY ?
            uint(_amount * _price).div(1 ether).toUint128() :
            uint(_amount * 1 ether).div(_price).toUint128();
    }


    function getNearestLimitOrder(uint64 _marketId, orderSide _side) public view returns (uint128) {
        Market storage market = markets[_marketId];
        uint64[] storage marketOrders = _side == orderSide.BUY ? market.buyLimitOrders : market.sellLimitOrders;
        return marketOrders.getTop();
    }

    function getPairs() external override view returns(string[] memory bases, string[] memory quotes, address[] memory basesAddr, address[] memory quotesAddr)
    {
        uint _marketId = freeMarketId - 1;
        bases = new string[](_marketId);
        quotes = new string[](_marketId);
        basesAddr = new address[](_marketId);
        quotesAddr = new address[](_marketId);
        for (uint i = 0; i < _marketId; i++) {
            address base = markets[i + 1].base;
            address quote = markets[i + 1].quote;
            bases[i] = base == ETH ? "ETH" : IERC20Metadata(base).symbol();
            quotes[i] = quote == ETH ? "ETH" : IERC20Metadata(quote).symbol();
            basesAddr[i] = base;
            quotesAddr[i] = quote;
        }
    }
	
    function getPrice(uint64 _marketId) external override view returns (uint128) 
    {
        return uint(getNearestLimitOrder(_marketId, orderSide.BUY) + getNearestLimitOrder(_marketId, orderSide.SELL)).div(2).toUint128();
    }

    function getMarketOrders(uint64 _marketId, orderSide _side, orderType _type) external override view returns (Order[] memory, uint64[] memory) 
    {
        Market storage market = markets[_marketId];
        return _getOrders(_side == orderSide.BUY ? 
            (_type == orderType.LIMIT ? market.buyLimitOrders : market.buyStopOrders) :
            (_type == orderType.LIMIT ? market.sellLimitOrders : market.sellStopOrders));
    }

    function getUserOrders(address _user) external override view returns (Order[] memory, uint64[] memory) 
    {
        return _getOrders(users[_user].orders);
    }

    function _getOrders(uint64[] memory ids) private view returns (Order[] memory, uint64[] memory)
    {
        Order[] memory o = new Order[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            o[i] = orders[ids[i]];
        }
        return (o, ids);
    }
}