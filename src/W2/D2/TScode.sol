/**

补充完整getDataByABI，对getData函数签名及参数进行编码，调用成功后解码并返回数据
补充完整setDataByABI1，使用abi.encodeWithSignature()编码调用setData函数，确保调用能够成功
补充完整setDataByABI2，使用abi.encodeWithSelector()编码调用setData函数，确保调用能够成功
补充完整setDataByABI3，使用abi.encodeCall()编码调用setData函数，确保调用能够成功
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DataStorage {
    string private data;

    function setData(string memory newData) public {
        data = newData;
    }

    function getData() public view returns (string memory) {
        return data;
    }
}

contract DataConsumer {
    address private dataStorageAddress;

    constructor(address _dataStorageAddress) {
        dataStorageAddress = _dataStorageAddress;
    }

    function getDataByABI() public returns (string memory) {
        // payload
        bytes memory payload = abi.encodeWithSignature("getData()");
        (bool success, bytes memory data) = dataStorageAddress.call(payload);
        require(success, "call function failed");

        return abi.decode(data, (string));
        // return data
    }

    function setDataByABI1(string calldata newData) public returns (bool) {
        // playload
        bytes memory payload = abi.encodeWithSignature("setData(string)", newData);
        (bool success, ) = dataStorageAddress.call(payload);
        require(success, "call function failed");
        return success;
    }

    function setDataByABI2(string calldata newData) public returns (bool) {
        // selector
        bytes4 selector = bytes4(keccak256("setData(string)"));
        // playload
        bytes memory payload = abi.encodeWithSelector(selector, newData);
        (bool success, ) = dataStorageAddress.call(payload);
        require(success, "call function failed");
        return success;
    }

    function setDataByABI3(string calldata newData) public returns (bool) {
        // playload
        bytes memory payload = abi.encodeCall(DataStorage.setData, (newData));
        (bool success, ) = dataStorageAddress.call(payload);
        require(success, "call function failed");
        return success;
    }
}

