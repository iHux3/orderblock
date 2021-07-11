// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IPriorityList.sol";

library PriorityList {
    function compare(uint64 value1, uint64 value2) internal view returns (bool) {
        //larger value priority ---> return value1 >= value2;
        return IPriorityList(address(this)).compare(value1, value2);
    }
    
    // before you can use priority list, this function has to be called for proper working of the list
    function init(IPriorityList.Data[] storage data, uint size) internal {
        if (size < 4) size = 4;
        data.push(IPriorityList.Data(0, 0)); // holds starting index
        data.push(IPriorityList.Data(0, 2)); // holds empty index
        for (uint64 i = 3; i < size; i++) {
            data.push(IPriorityList.Data(i, 0)); // value 
        }
        data.push(IPriorityList.Data(0, 0)); // value 
    }
    
    // O(n) - the less priority, the more gas cost
    function insert(IPriorityList.Data[] storage data, uint64 value) internal {
        uint64 start = data[0].value;
        uint64 empty = data[1].value;
        
        data[empty].value = value;
        uint64 nextEmpty = data[empty].next;
        data[1].value = nextEmpty;
        if (data[nextEmpty].next == 0) {
            expandArray(data);
        }
        
        // if there is no inserted value yet
        if (start == 0) {
            data[0].value = empty;
            data[empty].next = 0;
            return;
        }
        
        // find index where to insert and insert
        uint64 currentValue = data[start].value;
        if (compare(value, currentValue)) {
            data[empty].next = start;
            data[0].value = empty;
        } else {
            uint64 current = start;
            uint64 next = data[start].next;
            while (next != 0) {
                uint64 nextValue = data[next].value;
                if (compare(value, nextValue)) break;
                current = next;
                next = data[current].next;
            }
            data[empty].next = data[current].next;
            data[current].next = empty;
        }
    }
    
    // O(1)
    function getFirst(IPriorityList.Data[] storage data) internal view returns (uint64, uint64) {
        uint64 start = data[0].value;
        return (data[start].value, start);
    }
    
    // O(1)
    function removeFirst(IPriorityList.Data[] storage data) internal {
        uint64 start = data[0].value;
        require(start != 0);
        
        removeByIndex(data, start);
    }
    
    // O(1)
    function removeByIndex(IPriorityList.Data[] storage data, uint64 index) internal {
        uint64 start = data[0].value;
        require(start != 0);
        
        uint64 empty = data[1].value;
        data[0].value = data[index].next;
        data[index].next = empty;
        data[1].value = start;
    }
    
    
    // O(1)
    function getByIndex(IPriorityList.Data[] storage data, uint64 index) internal view returns (uint64, uint64) {
        if (index < 2) return getFirst(data);
        uint64 current = data[index].next;
        if (current == 0) return (0, 0);
        return (data[current].value, current);
    } 
    
    // O(n)
    function getAllValues(IPriorityList.Data[] storage data) internal view returns (uint64[] memory) {
        uint64[] memory values = new uint64[](data.length - 3);
        uint64 current = data[0].value;
        uint i = 0;
        while (current != 0) {
            values[i] = data[current].value;
            current = data[current].next;
            i++;
        }
        return values;
    }
    
    function expandArray(IPriorityList.Data[] storage data) private {
        uint64 len = uint64(data.length);
        data[len - 1].next = len;
        for (uint64 i = 0; i < len - 1; i++) {
            data.push(IPriorityList.Data(len + i + 1, 0));
        }
        data.push(IPriorityList.Data(0, 0));
    }
}