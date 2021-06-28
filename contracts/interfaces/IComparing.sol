// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComparing {
    function compare(uint value1, uint value2) external view returns (bool);
}