// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IOrderBlock.sol";

library Utils {
    using SafeCast for uint;
    using SafeERC20 for IERC20;

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function transfer(address tokenAddress, address sender, address receiver, uint amount) external 
    {
        if (tokenAddress == ETH) {
            payable(receiver).call{value: amount}("");
        } else {
            if (sender != msg.sender) {
                IERC20(tokenAddress).safeTransfer(receiver, amount);
            } else {
                IERC20(tokenAddress).safeTransferFrom(sender, receiver, amount);
            }
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
        address tokenAddress) external
    {
        require(uint8(_type) < 3, "INVALID_TYPE");

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
                uint price = (uint(nearestBuyLimit) + uint(nearestSellLimit)) / 2;
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
            require(msg.value == _amount, "GIVEN AMOUNT != ETH SENT");
        } else {
            IERC20 token = IERC20(tokenAddress);
            require(token.balanceOf(msg.sender) >= _amount, 'NO_TOKEN_BALANCE');
            require(token.allowance(msg.sender, address(this)) >= _amount, 'NO_TOKEN_ALLOWANCE');

            if (_type != IOrderBlock.orderType.MARKET) {
                token.safeTransferFrom(msg.sender, address(this), _amount);
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
}