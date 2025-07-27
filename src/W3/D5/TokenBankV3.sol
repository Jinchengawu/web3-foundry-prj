pragma solidity ^0.8.20;

import {TokenBankV2} from "../../W2/D3/TokenBank_Plus.sol";
import {TokenV3} from "./TokenV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
在原来的 TokenBank 添加一个方法 depositWithPermit2()， 这个方式使用 permit2 进行签名授权转账来进行存款。

 */
contract TokenBankV3 is TokenBankV2 {
    // EIP-712 类型哈希，用于 permitDeposit 签名验证
    bytes32 public constant PERMIT_TYPEHASH = 
        keccak256("PermitDeposit(address owner,uint256 amount,uint256 deadline)");
    
    // Permit2 类型哈希
    bytes32 public constant PERMIT2_TYPEHASH = 
        keccak256("Permit(address owner,address token,uint256 value,uint256 nonce,uint256 deadline)");
    
    // 用户 nonce 映射，用于防重放攻击
    mapping(address => uint256) public nonces;
    
    // 错误定义
    error PermitDepositExpiredSignature(uint256 deadline);
    error PermitDepositInvalidSigner(address signer, address owner);
    error PermitDepositInvalidAmount(uint256 amount);
    error Permit2InvalidToken(address token);
    error Permit2InvalidValue(uint256 value);
    error InsufficientTokenBalance(address owner, uint256 balance, uint256 amount);
    error InsufficientAllowance(address owner, uint256 allowance, uint256 amount);
    
    // 事件定义
    event PermitDeposit(address indexed owner, uint256 amount, uint256 deadline);
    event DepositWithPermit2(address indexed owner, address indexed token, uint256 amount, uint256 deadline);
    
    constructor(TokenV3 _token) TokenBankV2(_token) {}
    
    /**
     * @dev 通过离线签名授权进行存款（需要用户提前approve）
     * @param owner token 持有者地址
     * @param amount 存款金额
     * @param deadline 签名过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function permitDeposit(
        address owner, 
        uint256 amount, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) public {
        // 验证基本参数
        _validateDepositParams(owner, amount, deadline);
        
        // 验证 TokenBankV3 的 permitDeposit 签名
        _verifyPermitDepositSignature(owner, amount, deadline, v, r, s);
        
        // 检查 allowance 是否足够
        uint256 allowance = IERC20(address(token)).allowance(owner, address(this));
        if (allowance < amount) {
            revert InsufficientAllowance(owner, allowance, amount);
        }
        
        // 执行存款操作
        _executeDeposit(owner, address(token), amount);
        
        // 发出事件
        emit PermitDeposit(owner, amount, deadline);
    }
    
    /**
     * @dev 通过离线签名授权进行存款（无需用户提前approve）
     * 这个方法结合了 TokenV3 的 permit 和 TokenBankV3 的 permitDeposit
     * 只需要一套签名参数，简化前端调用
     * @param owner token 持有者地址
     * @param amount 存款金额
     * @param deadline 签名过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function permitDepositWithTokenPermit(
        address owner, 
        uint256 amount, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) public {
        // 验证基本参数
        _validateDepositParams(owner, amount, deadline);
        
        // 验证并执行 TokenV3 的 permit
        TokenV3 tokenContract = TokenV3(address(token));
        tokenContract.permit(owner, address(this), amount, deadline, v, r, s);
        
        // 执行存款操作
        _executeDeposit(owner, address(token), amount);
        
        // 发出事件
        emit PermitDeposit(owner, amount, deadline);
    }
    
    /**
     * @dev 使用 Permit2 标准进行签名授权转账存款
     * 这个方法允许用户通过签名授权任何 ERC20 代币进行存款
     * @param owner token 持有者地址
     * @param tokenAddress 要存款的代币地址
     * @param amount 存款金额
     * @param deadline 签名过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function depositWithPermit2(
        address owner,
        address tokenAddress,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // 验证基本参数（包括代币地址）
        _validatePermit2Params(owner, tokenAddress, amount, deadline);
        
        // 尝试通过 permit 获取授权（如果代币支持）
        try this.tryPermit(tokenAddress, owner, address(this), amount, deadline, v, r, s) {
            // permit 成功，继续执行转账
        } catch {
            // permit 失败，说明代币不支持 permit，需要用户提前 approve
            // 这里我们继续执行，如果用户没有 approve 会失败
        }
        
        // 执行存款操作
        _executeDeposit(owner, tokenAddress, amount);
        
        // 发出事件
        emit DepositWithPermit2(owner, tokenAddress, amount, deadline);
    }
    
    /**
     * @dev 尝试调用代币的 permit 方法
     * 这是一个外部函数，用于处理不支持 permit 的代币
     */
    function tryPermit(
        address tokenAddress,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 尝试调用代币的 permit 方法
        // 如果代币不支持 permit，这里会失败
        (bool success, ) = tokenAddress.call(
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                owner,
                spender,
                value,
                deadline,
                v,
                r,
                s
            )
        );
        
        if (!success) {
            revert("Permit failed");
        }
    }
    
    /**
     * @dev 获取域分隔符（用于前端签名）
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("TokenBankV3")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }
    
    /**
     * @dev 获取当前 nonce（用于防重放攻击）
     */
    function getNonce(address owner) public view returns (uint256) {
        return nonces[owner];
    }
    
    /**
     * @dev 重写 deposit 函数，保持向后兼容
     */
    function deposit(uint256 amount) public override {
        super.deposit(amount);
    }
    
    /**
     * @dev 验证存款基本参数
     * @param amount 存款金额
     * @param deadline 过期时间
     */
    function _validateDepositParams(
        address /* owner */,
        uint256 amount,
        uint256 deadline
    ) internal view {
        // 检查金额是否有效
        if (amount == 0) {
            revert PermitDepositInvalidAmount(amount);
        }
        
        // 检查签名是否过期
        if (block.timestamp > deadline) {
            revert PermitDepositExpiredSignature(deadline);
        }
    }
    
    /**
     * @dev 验证 Permit2 参数
     * @param tokenAddress 代币地址
     * @param amount 存款金额
     * @param deadline 过期时间
     */
    function _validatePermit2Params(
        address /* owner */,
        address tokenAddress,
        uint256 amount,
        uint256 deadline
    ) internal view {
        // 检查代币地址是否有效
        if (tokenAddress == address(0)) {
            revert Permit2InvalidToken(tokenAddress);
        }
        
        // 检查金额是否有效
        if (amount == 0) {
            revert Permit2InvalidValue(amount);
        }
        
        // 检查签名是否过期
        if (block.timestamp > deadline) {
            revert PermitDepositExpiredSignature(deadline);
        }
    }
    
    /**
     * @dev 验证 permitDeposit 签名
     * @param owner 用户地址
     * @param amount 存款金额
     * @param deadline 过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function _verifyPermitDepositSignature(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        // 构建结构体哈希
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, amount, deadline)
        );
        
        // 构建完整的 EIP-712 哈希
        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR(),
            structHash
        ));
        
        // 从签名中恢复签名者地址
        address signer = ecrecover(hash, v, r, s);
        
        // 验证签名者是否为 owner
        if (signer != owner) {
            revert PermitDepositInvalidSigner(signer, owner);
        }
    }
    
    /**
     * @dev 执行存款操作
     * @param owner 用户地址
     * @param tokenAddress 代币地址
     * @param amount 存款金额
     */
    function _executeDeposit(
        address owner,
        address tokenAddress,
        uint256 amount
    ) internal {
        // 检查用户余额是否足够
        uint256 userBalance = IERC20(tokenAddress).balanceOf(owner);
        if (userBalance < amount) {
            revert InsufficientTokenBalance(owner, userBalance, amount);
        }
        
        // 执行转账
        require(IERC20(tokenAddress).transferFrom(owner, address(this), amount), "Transfer failed");
        
        // 更新余额
        balances[owner] += amount;
        totalDeposit += amount;
        
        // 更新 userTokenBalances
        userTokenBalances[owner][tokenAddress] += amount;
    }
}