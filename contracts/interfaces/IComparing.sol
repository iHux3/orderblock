// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComparing {
    function compare(uint64 value1, uint64 value2) external view returns (bool);
}