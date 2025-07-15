/**
完善ABIEncoder合约的encodeUint和encodeMultiple函数，使用abi.encode对参数进行编码并返回
完善ABIDecoder合约的decodeUint和decodeMultiple函数，使用abi.decode将字节数组解码成对应类型的数据

 */

pragma solidity ^0.8.0;

contract ABIEncoder {
    function encodeUint(uint256 value) public pure returns (bytes memory) {
        //
        return abi.encode(value)
    }

    function encodeMultiple(
        uint num,
        string memory text
    ) public pure returns (bytes memory) {
       //
       return abi.encode(num,text)
    }
}

contract ABIDecoder {
    function decodeUint(bytes memory data) public pure returns (uint) {
        //
        return abi.decode(data, (uint))
    }

    function decodeMultiple(
        bytes memory data
    ) public pure returns (uint, string memory) {
        //
        (uint num, string memory text) = abi.decode(data, (uint, string));
        return (num, text)
    }
}