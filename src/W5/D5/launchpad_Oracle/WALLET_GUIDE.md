# Cast Wallet 管理指南

## 概述

`cast wallet` 是 Foundry 工具链中用于管理以太坊钱包的命令行工具。它提供了创建、导入、列出和管理钱包的完整功能。

## 基本命令

### 1. 查看钱包列表
```bash
cast wallet list
```
**功能**：显示所有已保存的钱包
**输出示例**：
```
my_wallet (Local)
test_wallet (Local)
```

### 2. 创建新钱包

#### 2.1 创建简单钱包（无加密）
```bash
cast wallet new
```
**功能**：创建一个新的随机密钥对
**输出示例**：
```
Successfully created new keypair.
Address:     0x48166B5d7cd5Cb836B432557eA006d3E8AAe2699
Private key: 0xe83423ea2043a40a03f5c6a1141af88238b205f7f6aaf6a1e0c6a682748bea79
```

#### 2.2 创建加密钱包
```bash
cast wallet new ~/.foundry/keystores/ wallet_name --unsafe-password your_password
```
**参数说明**：
- `~/.foundry/keystores/`：钱包存储目录
- `wallet_name`：钱包名称
- `--unsafe-password`：钱包密码（明文，不安全）

**输出示例**：
```
Created new encrypted keystore file: /Users/username/.foundry/keystores/wallet_name
Address: 0x0535D75d1292a620cd046F93718cA86730Bf042C
```

#### 2.3 交互式创建加密钱包
```bash
cast wallet new ~/.foundry/keystores/ wallet_name --password
```
**功能**：交互式输入密码，更安全

### 3. 导入现有钱包

#### 3.1 导入私钥
```bash
cast wallet import ~/.foundry/keystores/ wallet_name --unsafe-password your_password
```
**功能**：将现有私钥导入到加密钱包中

#### 3.2 从助记词生成私钥
```bash
cast wallet private-key "your mnemonic phrase"
```
**功能**：从助记词生成私钥

### 4. 钱包操作

#### 4.1 获取钱包地址
```bash
cast wallet address wallet_name
```
**功能**：显示指定钱包的地址

#### 4.2 签名消息
```bash
cast wallet sign wallet_name "message to sign"
```
**功能**：使用指定钱包签名消息

#### 4.3 验证签名
```bash
cast wallet verify address signature "message"
```
**功能**：验证消息签名

### 5. 管理钱包

#### 5.1 删除钱包
```bash
cast wallet remove wallet_name
```
**功能**：从存储中删除指定钱包

#### 5.2 修改密码
```bash
cast wallet change-password wallet_name
```
**功能**：修改钱包密码

## 实际使用示例

### 示例1：为Oracle项目创建钱包

```bash
# 1. 创建项目钱包
cast wallet new ~/.foundry/keystores/ oracle_wallet --unsafe-password oracle123

# 2. 查看钱包列表
cast wallet list

# 3. 获取钱包地址
cast wallet address oracle_wallet
```

### 示例2：使用钱包部署合约

```bash
# 1. 设置环境变量
export PRIVATE_KEY=$(cast wallet private-key oracle_wallet --password oracle123)

# 2. 部署Oracle合约
forge script src/W5/D5/launchpad_Oracle/DeployOracle.s.sol --rpc-url <RPC_URL> --broadcast
```

### 示例3：使用钱包进行交易

```bash
# 1. 发送ETH
cast send --value 0.1ether --to 0x... --from oracle_wallet --password oracle123

# 2. 调用合约函数
cast send --to <CONTRACT_ADDRESS> "updatePrice(uint256)" 1000000000000000000 --from oracle_wallet --password oracle123
```

## 安全最佳实践

### 1. 密码管理
- ✅ 使用强密码
- ✅ 不要在命令行中明文显示密码
- ✅ 定期更换密码
- ❌ 不要使用 `--unsafe-password` 在生产环境

### 2. 钱包存储
- ✅ 将钱包文件存储在安全位置
- ✅ 定期备份钱包文件
- ✅ 使用加密存储
- ❌ 不要将私钥明文存储

### 3. 环境变量
```bash
# 推荐：使用环境变量存储私钥
export PRIVATE_KEY="your_private_key"

# 在脚本中使用
forge script DeployOracle.s.sol --rpc-url $RPC_URL --broadcast
```

## 常见问题解决

### 1. 钱包列表为空
```bash
# 检查钱包存储目录
ls -la ~/.foundry/keystores/

# 如果目录不存在，创建它
mkdir -p ~/.foundry/keystores/
```

### 2. 密码错误
```bash
# 重置钱包密码
cast wallet change-password wallet_name
```

### 3. 权限问题
```bash
# 检查文件权限
chmod 600 ~/.foundry/keystores/*

# 确保只有所有者可以访问
chown $USER ~/.foundry/keystores/*
```

## 高级功能

### 1. 批量创建钱包
```bash
# 创建多个钱包
cast wallet new ~/.foundry/keystores/ --number 5 --unsafe-password test123
```

### 2. 生成虚荣地址
```bash
# 生成以特定字符开头的地址
cast wallet vanity --starts-with 0x123
```

### 3. 从助记词创建钱包
```bash
# 生成助记词
cast wallet new-mnemonic

# 从助记词生成私钥
cast wallet private-key "your mnemonic phrase"
```

## 与Oracle项目的集成

### 1. 创建Oracle专用钱包
```bash
# 创建Oracle管理员钱包
cast wallet new ~/.foundry/keystores/ oracle_admin --unsafe-password admin123

# 创建价格更新者钱包
cast wallet new ~/.foundry/keystores/ price_updater --unsafe-password updater123
```

### 2. 部署脚本配置
```bash
#!/bin/bash
# deploy_oracle.sh

# 设置钱包
export ORACLE_ADMIN_KEY=$(cast wallet private-key oracle_admin --password admin123)
export PRICE_UPDATER_KEY=$(cast wallet private-key price_updater --password updater123)

# 部署合约
forge script src/W5/D5/launchpad_Oracle/DeployOracle.s.sol --rpc-url $RPC_URL --broadcast

# 配置Oracle
cast send --to $ORACLE_ADDRESS "addAuthorizedUpdater(address)" $PRICE_UPDATER_ADDRESS --from oracle_admin --password admin123
```

### 3. 自动化价格更新
```bash
#!/bin/bash
# update_price.sh

# 更新价格
cast send --to $ORACLE_ADDRESS "updatePrice(uint256)" $NEW_PRICE --from price_updater --password updater123

# 获取TWAP
cast call --to $ORACLE_ADDRESS "getDefaultTWAP()"
```

## 总结

通过 `cast wallet` 命令，您可以：

1. **安全管理**：创建和管理加密钱包
2. **自动化部署**：在脚本中使用钱包进行合约部署
3. **权限控制**：为不同角色创建不同的钱包
4. **集成开发**：与Foundry工具链无缝集成

这些功能使得钱包管理变得更加简单和安全，特别适合智能合约开发和DeFi项目部署。 