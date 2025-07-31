pragma solidity ^0.8.0;

/**
 * 使用Solidity内联汇编修改合约Owner地址
 * 演示如何通过内联汇编直接操作存储槽来修改owner
 */

contract MyWallet { 
    string public name;
    mapping (address => bool) private approved;
    address public owner;

    modifier auth {
        require (msg.sender == owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    } 

    function transferOwnership(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        require(owner != _addr, "New owner is the same as the old owner");
        owner = _addr;
    }

    /**
     * 使用内联汇编修改owner地址
     * 直接操作存储槽来修改owner
     */
    function transferOwnershipWithAssembly(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        require(owner != _addr, "New owner is the same as the old owner");
        
        assembly {
            // 将新owner地址存储到owner变量的存储槽中
            // owner变量在合约中的存储位置是第2个槽（第0个是name，第1个是approved）
            sstore(2, _addr)
        }
    }

    /**
     * 使用内联汇编读取owner地址
     */
    function getOwnerWithAssembly() public view returns (address) {
        address currentOwner;
        assembly {
            // 从存储槽2读取owner地址
            currentOwner := sload(2)
        }
        return currentOwner;
    }

    /**
     * 使用内联汇编直接修改owner（危险操作，仅用于演示）
     * 注意：这个函数没有权限检查，仅用于演示内联汇编的使用
     */
    function dangerousTransferOwnership(address _addr) public {
        require(_addr != address(0), "New owner is the zero address");
        
        assembly {
            // 直接修改存储槽2（owner的位置）
            sstore(2, _addr)
        }
    }

    /**
     * 使用内联汇编批量操作存储
     */
    function batchUpdateWithAssembly(address _newOwner, string memory _newName) public auth {
        require(_newOwner != address(0), "New owner is the zero address");
        
        assembly {
            // 更新owner（存储槽2）
            sstore(2, _newOwner)
            
            // 更新name（存储槽0）
            // 注意：string类型需要特殊处理，这里简化处理
            // 实际应用中需要处理string的复杂存储结构
        }
    }
}