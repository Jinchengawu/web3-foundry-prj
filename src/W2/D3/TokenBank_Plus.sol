pragma solidity ^0.8.0;
import { TokenBank } from "../D2/TokenBank.sol";
import { ERC20V2 } from "./ERC20_Plus.sol";
/***
继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，
用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。
 */

contract TokenBankV2 is TokenBank {
    // userAddress => tokenAddress => amount
    mapping(address => mapping(address => uint256)) public userTokenBalances;
    address public tokenBankOwner;

    constructor(ERC20V2 _token) TokenBank(_token) {
        tokenBankOwner = msg.sender;
    }

    function deposit(uint256 amount) public override {
        super.deposit(amount);
    }
    
    function tokensReceived(address from, uint256 amount, address token) public {
        // 检查调用者是否为受信任的 token 合约
        require(msg.sender == token, "Only token contract can call");
        // 更新余额
        userTokenBalances[from][token] += amount;
        // 可以加事件
    }
}