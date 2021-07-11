// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriorityList {
    struct Data {
        uint64 next;
        uint64 value;
    }
    function compare(uint64 value1, uint64 value2) external view returns (bool);
}
