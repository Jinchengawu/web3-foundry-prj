const { ethers } = require("hardhat");

/**
 * RebaseToken 使用示例脚本
 * 演示通缩型Token的核心功能
 */
async function main() {
    console.log("=== RebaseToken 使用示例 ===\n");

    // 获取部署者账户
    const [deployer, user1, user2] = await ethers.getSigners();
    console.log("部署者地址:", deployer.address);
    console.log("用户1地址:", user1.address);
    console.log("用户2地址:", user2.address);
    console.log("部署者余额:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\n");

    // 部署合约
    console.log("正在部署 RebaseToken 合约...");
    const RebaseToken = await ethers.getContractFactory("RebaseToken");
    const rebaseToken = await RebaseToken.deploy("Rebase Token", "RBT");
    await rebaseToken.waitForDeployment();
    
    const contractAddress = await rebaseToken.getAddress();
    console.log("合约地址:", contractAddress);
    console.log("Token名称:", await rebaseToken.name());
    console.log("Token符号:", await rebaseToken.symbol());
    console.log("初始总供应量:", ethers.formatEther(await rebaseToken.totalSupply()), "RBT");
    console.log("初始Rebase指数:", ethers.formatEther(await rebaseToken.getRebaseIndex()));
    console.log("年通缩率:", await rebaseToken.getAnnualDeflation(), "(1% = 100)\n");

    // 演示1: 初始状态
    console.log("=== 演示1: 初始状态 ===");
    const deployerBalance = await rebaseToken.balanceOf(deployer.address);
    console.log("部署者余额:", ethers.formatEther(deployerBalance), "RBT");
    console.log("用户1余额:", ethers.formatEther(await rebaseToken.balanceOf(user1.address)), "RBT");
    console.log("用户2余额:", ethers.formatEther(await rebaseToken.balanceOf(user2.address)), "RBT\n");

    // 演示2: 转账功能
    console.log("=== 演示2: 转账功能 ===");
    const transferAmount = ethers.parseEther("10000000"); // 1000万枚
    console.log("转账给用户1:", ethers.formatEther(transferAmount), "RBT");
    
    const tx1 = await rebaseToken.transfer(user1.address, transferAmount);
    await tx1.wait();
    
    console.log("转账后部署者余额:", ethers.formatEther(await rebaseToken.balanceOf(deployer.address)), "RBT");
    console.log("转账后用户1余额:", ethers.formatEther(await rebaseToken.balanceOf(user1.address)), "RBT\n");

    // 演示3: 授权转账
    console.log("=== 演示3: 授权转账 ===");
    const approveAmount = ethers.parseEther("5000000"); // 500万枚
    console.log("授权用户1使用:", ethers.formatEther(approveAmount), "RBT");
    
    const tx2 = await rebaseToken.approve(user1.address, approveAmount);
    await tx2.wait();
    
    console.log("授权额度:", ethers.formatEther(await rebaseToken.allowance(deployer.address, user1.address)), "RBT");
    
    // 用户1使用授权转账给用户2
    const useAmount = ethers.parseEther("2000000"); // 200万枚
    console.log("用户1使用授权转账给用户2:", ethers.formatEther(useAmount), "RBT");
    
    const tx3 = await rebaseToken.connect(user1).transferFrom(deployer.address, user2.address, useAmount);
    await tx3.wait();
    
    console.log("转账后用户2余额:", ethers.formatEther(await rebaseToken.balanceOf(user2.address)), "RBT");
    console.log("剩余授权额度:", ethers.formatEther(await rebaseToken.allowance(deployer.address, user1.address)), "RBT\n");

    // 演示4: 模拟时间推进并执行Rebase
    console.log("=== 演示4: 执行Rebase ===");
    console.log("当前时间:", new Date().toLocaleString());
    
    // 注意：在实际环境中，我们需要等待足够的时间间隔
    // 这里我们使用hardhat的time manipulation功能来模拟
    console.log("模拟时间推进1天...");
    
    // 获取当前区块时间
    const currentBlock = await ethers.provider.getBlock("latest");
    const newTime = currentBlock.timestamp + 24 * 60 * 60; // 1天后
    
    // 使用hardhat的time manipulation（需要配置）
    await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
    await ethers.provider.send("evm_mine");
    
    console.log("新时间:", new Date(newTime * 1000).toLocaleString());
    
    // 执行rebase
    console.log("执行Rebase操作...");
    const tx4 = await rebaseToken.rebase();
    await tx4.wait();
    
    // 查看rebase后的状态
    const newRebaseIndex = await rebaseToken.getRebaseIndex();
    const newTotalSupply = await rebaseToken.totalSupply();
    
    console.log("新的Rebase指数:", ethers.formatEther(newRebaseIndex));
    console.log("新的总供应量:", ethers.formatEther(newTotalSupply), "RBT");
    console.log("Rebase后部署者余额:", ethers.formatEther(await rebaseToken.balanceOf(deployer.address)), "RBT");
    console.log("Rebase后用户1余额:", ethers.formatEther(await rebaseToken.balanceOf(user1.address)), "RBT");
    console.log("Rebase后用户2余额:", ethers.formatEther(await rebaseToken.balanceOf(user2.address)), "RBT\n");

    // 演示5: 验证余额比例保持不变
    console.log("=== 演示5: 验证余额比例保持不变 ===");
    const totalSupplyAfterRebase = await rebaseToken.totalSupply();
    
    const deployerRatio = (await rebaseToken.balanceOf(deployer.address) * 10000n) / totalSupplyAfterRebase;
    const user1Ratio = (await rebaseToken.balanceOf(user1.address) * 10000n) / totalSupplyAfterRebase;
    const user2Ratio = (await rebaseToken.balanceOf(user2.address) * 10000n) / totalSupplyAfterRebase;
    
    console.log("部署者占比:", Number(deployerRatio) / 100, "%");
    console.log("用户1占比:", Number(user1Ratio) / 100, "%");
    console.log("用户2占比:", Number(user2Ratio) / 100, "%");
    console.log("总占比:", Number(deployerRatio + user1Ratio + user2Ratio) / 100, "%\n");

    // 演示6: 获取合约信息
    console.log("=== 演示6: 合约信息 ===");
    const contractInfo = await rebaseToken.getContractInfo();
    console.log("原始总供应量:", ethers.formatEther(contractInfo.totalSupply_), "RBT");
    console.log("当前Rebase指数:", ethers.formatEther(contractInfo.rebaseIndex_));
    console.log("上次Rebase时间:", new Date(Number(contractInfo.lastRebaseTime_) * 1000).toLocaleString());
    console.log("年通缩率:", Number(contractInfo.annualDeflation_), "(1% = 100)");
    console.log("实际总供应量:", ethers.formatEther(contractInfo.actualTotalSupply), "RBT\n");

    // 演示7: 多次Rebase效果
    console.log("=== 演示7: 多次Rebase效果 ===");
    console.log("模拟执行5次Rebase...");
    
    for (let i = 1; i <= 5; i++) {
        // 推进时间
        const nextTime = newTime + i * 24 * 60 * 60;
        await ethers.provider.send("evm_setNextBlockTimestamp", [nextTime]);
        await ethers.provider.send("evm_mine");
        
        // 执行rebase
        const rebaseTx = await rebaseToken.rebase();
        await rebaseTx.wait();
        
        const currentIndex = await rebaseToken.getRebaseIndex();
        const currentSupply = await rebaseToken.totalSupply();
        
        console.log(`第${i}次Rebase后 - 指数: ${ethers.formatEther(currentIndex)}, 总供应量: ${ethers.formatEther(currentSupply)} RBT`);
    }
    
    console.log("\n=== 演示完成 ===");
    console.log("RebaseToken的核心功能演示完毕！");
    console.log("关键特性：");
    console.log("1. 每年1%的通缩机制");
    console.log("2. 用户余额比例保持不变");
    console.log("3. 完全兼容ERC20标准");
    console.log("4. 安全的数学计算");
}

// 错误处理
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("演示脚本执行失败:", error);
        process.exit(1);
    }); 