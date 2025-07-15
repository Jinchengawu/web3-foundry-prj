pragma solidity ^0.8.0;

contract Callee {
    function getData() public pure returns (uint256) {
        return 42;
    }
    fallback () external  {
        revert("staticcall function failed");
    }
}

contract Caller {
    function callGetData(address callee) public view returns (uint256 data) {
        // call by staticcall
        (bool success, bytes memory returnData) = callee.staticcall(
            abi.encodeWithSignature("getData()")
        );
        require(success, "staticcall failed");
        data = abi.decode(returnData, (uint256));
        return data;
    }
    
}


contract Caller2 {
    function sendEther(address to, uint256 value) public returns (bool) {
        // 使用 call 发送 ether
        this.call()
        return success;
    }

    receive() external payable {
        revert("sendEther failed");
    }
}


