// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestToken1 is ERC20 {
    constructor() ERC20('TestToken1', 'TEST1') 
    {
        _mint(msg.sender, 10000 ether);
    }
}