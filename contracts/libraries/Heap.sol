// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IComparing.sol";

library Heap {
    function compare(uint value1, uint value2) internal view returns (bool) {
        //max heap -> value1 > value2
        return IComparing(address(this)).compare(value1, value2);
    }
    
    function init(uint256 size) internal pure returns (uint128[] memory) {
        if (size < 2) size = 2;
        uint128[] memory data = new uint128[](size);
        data[0] = 1;
        return data;
    }
    
    // O(log(n))
    // adding zero not allowed
    function add(uint128[] storage data, uint128 value) internal {
        require(value != 0, "heap: adding zero");
        
        uint128 index = data[0];
        fixUp(data, index, value);
        uint256 len = data.length;
        if (index == len - 1) expandArray(data, len);
        data[0]++;
    }
    
    // O(log(n))
    function removeTop(uint128[] storage data) internal returns (uint128) {
        return remove(data, 1);
    }
    
    // O(n)
    function removeValue(uint128[] storage data, uint128 value) internal {
        for (uint128 i = 1; i < data[0]; i++) {
            if (data[i] == value) {
                remove(data, i);
                break;
            }
        }
    }
    
    // O(1)
    function getTop(uint128[] storage data) internal view returns (uint128) {
        return data[1];
    }
    
    function remove(uint128[] storage data, uint128 removeIndex) private returns (uint128) {
        uint128 index = data[0];
        require(index > 1, "heap: nothing to remove");

        uint128 toRemove = data[removeIndex];
        data[0]--;
        uint128 newValue = data[index];
        data[index] = 0;
        fixDown(data, removeIndex, newValue);
        return toRemove;
    }
    
    function fixDown(uint128[] storage data, uint128 index, uint128 value) private {
        uint128 childIndex = index * 2;
        uint128 leftChild = data[childIndex];
        if (childIndex < data.length && leftChild != 0) {
            uint128 rightChild = data[childIndex + 1];
            uint128 child = compare(leftChild, rightChild) ? leftChild : rightChild;
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
    
    function fixUp(uint128[] storage data, uint128 index, uint128 value) private {
        if (index > 1) {
            uint128 parentIndex = index / 2;
            uint128 parentValue = data[parentIndex];
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
    
    function expandArray(uint128[] storage data, uint256 count) private {
        for (uint256 i = 0; i < count; i++) {
            data.push();
        }
    }
}