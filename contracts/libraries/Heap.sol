// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IComparing.sol";

library Heap {
    function compare(uint64 value1, uint64 value2) internal view returns (bool) {
        //max heap -> value1 > value2
        return IComparing(address(this)).compare(value1, value2);
    }
    
    function init(uint256 size) internal pure returns (uint64[] memory) {
        if (size < 2) size = 2;
        uint64[] memory data = new uint64[](size);
        data[0] = 1;
        return data;
    }
    
    // O(log(n))
    // adding zero not allowed
    function add(uint64[] storage data, uint64 value) internal {
        require(value != 0, "heap: adding zero");
        uint64 index = data[0];
        require(index < type(uint64).max, "heap: full");

        fixUp(data, index, value);
        uint256 len = data.length;
        if (index == len - 1) expandArray(data, len);
        data[0]++;
    }
    
    // O(log(n))
    function removeTop(uint64[] storage data) internal returns (uint64) {
        return remove(data, 1);
    }
    
    // O(n)
    function removeValue(uint64[] storage data, uint64 value) internal {
        for (uint64 i = 1; i < data[0]; i++) {
            if (data[i] == value) {
                remove(data, i);
                break;
            }
        }
    }
    
    // O(1)
    function getTop(uint64[] storage data) internal view returns (uint64) {
        return data[1];
    }
    
    function remove(uint64[] storage data, uint64 removeIndex) private returns (uint64) {
        uint64 index = data[0];
        require(index > 1, "heap: nothing to remove");

        uint64 toRemove = data[removeIndex];
        data[0]--;
        uint64 newValue = data[index];
        data[index] = 0;
        fixDown(data, removeIndex, newValue);
        return toRemove;
    }
    
    function fixDown(uint64[] storage data, uint64 index, uint64 value) private {
        uint64 childIndex = index * 2;
        uint64 leftChild = data[childIndex];
        if (childIndex < data.length && leftChild != 0) {
            uint64 rightChild = data[childIndex + 1];
            uint64 child = compare(leftChild, rightChild) ? leftChild : rightChild;
            if (compare(child, value)) {
                data[index] = child;
                fixDown(data, leftChild == child ? childIndex : childIndex + 1, value);
            } else {
                data[index] = value;
            }
        } else {
            data[index] = value;
        }
    }
    
    function fixUp(uint64[] storage data, uint64 index, uint64 value) private {
        if (index > 1) {
            uint64 parentIndex = index / 2;
            uint64 parentValue = data[parentIndex];
            if (compare(value, parentValue)) {
                data[index] = parentValue;
                fixUp(data, parentIndex, value);
            } else {
                data[index] = value;
            }
        } else {
            data[1] = value;
        }
    }
    
    function expandArray(uint64[] storage data, uint256 count) private {
        for (uint256 i = 0; i < count; i++) {
            data.push();
        }
    }
}