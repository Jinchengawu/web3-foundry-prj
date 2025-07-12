# BigBank 挑战项目

## 项目结构

```
src/W1/D4/
├── IBank.sol          # IBank接口定义
├── Bigbank2.sol       # BigBank合约和Admin合约
├── BigBankWrapper.sol # BigBankWrapper合约（提供管理员转移功能）
└── README.md          # 项目说明文档
```

## 合约说明

### 1. IBank 接口 (`IBank.sol`)
定义了银行合约需要实现的基本方法：
- `deposit()` - 存款方法
- `withdraw(address _toAddress, uint256 amount)` - 提款方法

### 2. BigBank 合约 (`Bigbank2.sol`)
继承自原始的Bank合约，添加了以下功能：
- **最小存款限制**：使用`minimumDeposit`修饰符，要求存款金额 >= 0.001 ether
- **重写deposit方法**：应用最小存款限制
- **重写receive方法**：确保直接发送ETH也应用最小存款限制

### 3. BigBankWrapper 合约 (`BigBankWrapper.sol`)
包装BigBank合约，提供管理员转移功能：
- **管理员转移**：`transferOwnership(address newOwner)`方法
- **实现IBank接口**：通过代理模式调用BigBank的方法
- **权限控制**：只有owner可以调用withdraw和transferOwnership

### 4. Admin 合约 (`Bigbank2.sol`)
管理员合约，具有以下功能：
- **Owner管理**：有自己的owner地址
- **adminWithdraw方法**：调用IBank接口的withdraw方法，将银行资金转移到Admin合约
- **资金提取**：owner可以提取Admin合约中的资金

## 使用流程

1. **部署合约**：
   - 部署BigBankWrapper合约
   - 部署Admin合约

2. **用户存款**：
   - 用户向BigBankWrapper存款（金额 >= 0.001 ether）

3. **转移管理员**：
   - 将BigBankWrapper的管理员转移给Admin合约

4. **提取资金**：
   - Admin合约的owner调用`adminWithdraw`方法
   - 将BigBankWrapper中的资金转移到Admin合约

5. **最终提取**：
   - Admin合约的owner调用`withdrawFunds`方法
   - 将Admin合约中的资金提取到自己的地址

## 测试

运行测试命令：
```bash
forge test --match-contract BigBankTest -vv
```

## 部署

运行部署脚本：
```bash
forge script script/BigBankDeploy.s.sol --rpc-url <RPC_URL> --broadcast
```

注意：需要设置环境变量`PRIVATE_KEY`。

## 关键特性

1. **不修改原始Bank合约**：通过继承和包装的方式实现功能扩展
2. **最小存款限制**：使用modifier确保存款金额 >= 0.001 ether
3. **管理员转移**：BigBankWrapper支持转移管理员权限
4. **接口实现**：所有合约都正确实现了IBank接口
5. **权限控制**：严格的权限检查确保安全性 