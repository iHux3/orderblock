// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "hardhat/console.sol";
import "../interfaces/IOrderBlock.sol";

library Utils {
    using SafeMath for uint;
    using SafeCast for uint;
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint constant STOPORDER_FEE = 0;

    function _isFillable(IOrderBlock.OrderData memory data) external pure returns(bool)
    {
        uint totalAmountConverted;
        for (uint i = 0; i < data.marketOrders.length; i++) {
            if (data.marketOrders[i] != 0) {
                uint price = uint(data.prices[i] + data.bestPriceOpposite).div(2);
                if (data.slippage == 0 || (data.side == IOrderBlock.orderSide.BUY ? price <= data.slippage : price >= data.slippage)) {
                    totalAmountConverted += data.side == IOrderBlock.orderSide.BUY ?
                        uint(data.amounts[i] * data.prices[i]).div(1 ether).toUint128() :
                        uint(data.amounts[i] * 1 ether).div(data.prices[i]).toUint128();
                }
            }
        }
        return totalAmountConverted >= data.amount;
    }

    function transfer(address token, address sender, address receiver, uint amount) external 
    {
        if (token == ETH) {
            payable(receiver).transfer(amount);
        } else {
            if (sender != msg.sender) {
                IERC20(token).transfer(receiver, amount);
            } else {
                IERC20(token).transferFrom(sender, receiver, amount);
            }
        }
    }

    function verifyOrderInput(uint128 _price, uint128 _amount, IOrderBlock.orderSide _side, IOrderBlock.orderType _type, uint128 _slippage, 
        uint128 nearestBuyLimit, uint128 nearestSellLimit, address tokenAddress) external
    {
        require(uint8(_type) < 3, "INVALID_TYPE");
        require(uint8(_side) < 2, "INVALID_SIDE");

        //verify price
        require(_price >= 10 ** 9 && _price % 10 ** 9 == 0, "INVALID_PRICE");
        if (_type != IOrderBlock.orderType.MARKET) {
            if (_type == IOrderBlock.orderType.LIMIT) {
                if (_side == IOrderBlock.orderSide.BUY) {
                    if (nearestSellLimit != 0) require(_price < nearestSellLimit, "PRICE > BEST SELL PRICE");
                } else {
                    if (nearestBuyLimit != 0) require(_price > nearestBuyLimit, "PRICE < BEST BUY PRICE");
                }
            } else {
                uint price = uint(nearestBuyLimit + nearestSellLimit).div(2);
                if (price > 0) {
                    if (_side == IOrderBlock.orderSide.BUY) {
                        require(_price > price, "PRICE < ACTUAL PRICE");
                    } else {
                        require(_price < price, "PRICE > ACTUAL PRICE");
                    }
                }
            }
        }

        //verify amount
        require(_amount >= 10 ** 9 && _amount % 10 ** 9 == 0, "INVALID_AMOUNT");
        if (tokenAddress == ETH) {
            if (_type != IOrderBlock.orderType.STOP) {
                require(msg.value == _amount, "GIVEN AMOUNT != ETH SENT");
            } else {
                require(msg.value == _amount + STOPORDER_FEE, "NO_STOP_ORDER_FEE");
            }
        } else {
            IERC20 token = IERC20(tokenAddress);
            require(IERC20(token).balanceOf(msg.sender) >= _amount, 'NO_TOKEN_BALANCE');
            require(IERC20(token).allowance(msg.sender, address(this)) >= _amount, 'NO_TOKEN_ALLOWANCE');

            if (_type != IOrderBlock.orderType.MARKET) {
                token.transferFrom(msg.sender, address(this), _amount);
            }

            if (_type == IOrderBlock.orderType.STOP) {
                require(msg.value == STOPORDER_FEE, "NO_STOP_ORDER_FEE");
            }
        }

        //verify slippage
        if (_type == IOrderBlock.orderType.LIMIT) {
            require(_slippage == 0, "INVALID_SLIPPAGE");
        } else {
            if (_slippage > 0) {
                require(_side == IOrderBlock.orderSide.BUY ? _slippage > _price : _slippage < _price, "INVALID_SLIPPAGE");
            }
        }
    }

    function getNearestLimit(IOrderBlock.Market storage market, IOrderBlock.orderSide _side, mapping(uint => IOrderBlock.Order) storage orders) external view returns(uint128)
    {
        uint128[] storage marketOrdersStorage = _side == IOrderBlock.orderSide.BUY ? market.buyLimitOrders : market.sellLimitOrders;
        uint128[] memory marketOrders = marketOrdersStorage;
        uint128 bestPrice;

        for (uint i = 0; i < marketOrders.length; i++) {
            uint id = marketOrders[i];
            if (id != 0) {
                IOrderBlock.Order storage o = orders[marketOrders[i]];
                if (bestPrice == 0) {
                    bestPrice = o.price;
                } else {
                    uint128 price = o.price;
                    if (_side == IOrderBlock.orderSide.BUY ? price > bestPrice : price < bestPrice) {
                        bestPrice = price;
                    }
                }
            }
        }

        return bestPrice;
    }
}