// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IOrderBlock.sol";

library Utils {
    using SafeCast for uint;
    using SafeERC20 for IERC20;

    function transfer(IERC20 token, address sender, address receiver, uint amount) external 
    {
        if (sender != msg.sender) {
            token.safeTransfer(receiver, amount);
        } else {
            token.safeTransferFrom(sender, receiver, amount);
        }
    }

    function verifyOrderInput(
        uint128 _price, 
        uint128 _amount, 
        IOrderBlock.orderSide _side, 
        IOrderBlock.orderType _type, 
        uint128 _slippage, 
        uint128 nearestBuyLimit,
        uint128 nearestSellLimit, 
        IERC20 token,
        uint8 baseDecimals) external
    {
        require(uint8(_type) < 3, "INVALID_TYPE");

        //verify price
        if (_type != IOrderBlock.orderType.MARKET) {
            if (_type == IOrderBlock.orderType.LIMIT) {
                if (_side == IOrderBlock.orderSide.BUY) {
                    if (nearestSellLimit != 0) require(_price < nearestSellLimit, "PRICE > BEST SELL PRICE");
                } else {
                    if (nearestBuyLimit != 0) require(_price > nearestBuyLimit, "PRICE < BEST BUY PRICE");
                }
            } else {
                uint128 actualPrice;
                if (nearestBuyLimit != 0 && nearestSellLimit != 0) {
                    actualPrice = ((uint(nearestBuyLimit) + uint(nearestSellLimit)) / 2).toUint128();
                }

                if (actualPrice > 0) {
                    if (_side == IOrderBlock.orderSide.BUY) {
                        require(_price > actualPrice, "PRICE < ACTUAL PRICE");
                    } else {
                        require(_price < actualPrice, "PRICE > ACTUAL PRICE");
                    }
                }
            }

            //verify that amount is convertable to the other asset
            uint128 convertedAmount = convertOrderAmount(
                _side == IOrderBlock.orderSide.BUY ? IOrderBlock.orderSide.SELL : IOrderBlock.orderSide.BUY, 
                _amount, 
                _price, 
                baseDecimals
            );
            require(convertedAmount > 0, "INVALID_AMOUNT");
        } else {
            require(_price == 0, "INVALID_PRICE");
        }

        //verify amount
        require(token.balanceOf(msg.sender) >= _amount, 'NO_TOKEN_BALANCE');
        require(token.allowance(msg.sender, address(this)) >= _amount, 'NO_TOKEN_ALLOWANCE');

        if (_type != IOrderBlock.orderType.MARKET) {
            token.safeTransferFrom(msg.sender, address(this), _amount);
        }

        //verify slippage
        if (_type == IOrderBlock.orderType.LIMIT) {
            require(_slippage == 0, "INVALID_SLIPPAGE");
        } else {
            if (_slippage > 0) {
                if (_type == IOrderBlock.orderType.MARKET && nearestBuyLimit != 0 && nearestSellLimit != 0) {
                    _price = ((uint(nearestBuyLimit) + uint(nearestSellLimit)) / 2).toUint128();
                }

                require(_side == IOrderBlock.orderSide.BUY ? _slippage > _price : _slippage < _price, "INVALID_SLIPPAGE");
            }
        }
    }

    function convertOrderAmount(IOrderBlock.orderSide _side, uint128 _amount, uint128 _price, uint8 baseDecimals) internal pure returns (uint128) {
        return _side == IOrderBlock.orderSide.BUY ?
            (uint(_amount) * uint(_price) / 10**baseDecimals).toUint128() :
            (uint(_amount) * 10**baseDecimals / uint(_price)).toUint128();
    }
}