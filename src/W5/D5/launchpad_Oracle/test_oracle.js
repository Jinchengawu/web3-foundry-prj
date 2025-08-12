const { ethers } = require("hardhat");

async function main() {
    console.log("=== Oracle 合约功能验证 ===");
    
    try {
        // 获取合约工厂
        const Oracle = await ethers.getContractFactory("Oracle");
        
        // 部署合约
        console.log("正在部署 Oracle 合约...");
        const oracle = await Oracle.deploy();
        await oracle.deployed();
        
        console.log("✅ Oracle 合约已部署到:", oracle.address);
        
        // 获取部署者信息
        const [deployer] = await ethers.getSigners();
        console.log("部署者地址:", deployer.address);
        
        // 基础信息查询
        console.log("\n=== 合约基础信息 ===");
        console.log("所有者:", await oracle.owner());
        console.log("默认TWAP窗口:", (await oracle.DEFAULT_TWAP_WINDOW()).toString(), "秒");
        console.log("最大价格变化:", (await oracle.MAX_PRICE_CHANGE()).toString(), "%");
        console.log("合约状态:", await oracle.paused() ? "已暂停" : "正常运行");
        
        // 模拟价格更新
        console.log("\n=== 模拟价格更新 ===");
        
        const initialPrice = ethers.utils.parseEther("1.0"); // 1 ETH
        const price1 = ethers.utils.parseEther("1.2"); // 1.2 ETH
        const price2 = ethers.utils.parseEther("0.8"); // 0.8 ETH
        
        // 初始价格
        console.log("设置初始价格:", ethers.utils.formatEther(initialPrice), "ETH");
        await oracle.updatePrice(initialPrice);
        
        // 更新价格1
        console.log("更新价格到:", ethers.utils.formatEther(price1), "ETH");
        await oracle.updatePrice(price1);
        
        // 更新价格2
        console.log("更新价格到:", ethers.utils.formatEther(price2), "ETH");
        await oracle.updatePrice(price2);
        
        // 查询价格信息
        console.log("\n=== 价格信息查询 ===");
        
        const latestPrice = await oracle.getLatestPrice();
        console.log("最新价格:", ethers.utils.formatEther(latestPrice), "ETH");
        
        const pricePoint = await oracle.getLatestPricePoint();
        console.log("价格点信息:");
        console.log("  时间戳:", pricePoint.timestamp.toString());
        console.log("  价格:", ethers.utils.formatEther(pricePoint.price), "ETH");
        console.log("  累积价格:", ethers.utils.formatEther(pricePoint.cumulativePrice), "ETH");
        console.log("  累积时间:", pricePoint.cumulativeTime.toString(), "秒");
        
        // TWAP 计算
        console.log("\n=== TWAP 计算 ===");
        
        const twap1h = await oracle.getTWAP(3600); // 1小时
        const twap30m = await oracle.getTWAP(1800); // 30分钟
        const defaultTWAP = await oracle.getDefaultTWAP(); // 默认TWAP
        
        console.log("1小时TWAP:", ethers.utils.formatEther(twap1h), "ETH");
        console.log("30分钟TWAP:", ethers.utils.formatEther(twap30m), "ETH");
        console.log("默认TWAP:", ethers.utils.formatEther(defaultTWAP), "ETH");
        
        // 管理功能演示
        console.log("\n=== 管理功能演示 ===");
        
        // 添加授权更新者
        const newUpdater = ethers.Wallet.createRandom();
        console.log("添加授权更新者:", newUpdater.address);
        await oracle.addAuthorizedUpdater(newUpdater.address);
        
        // 验证授权
        const isAuthorized = await oracle.authorizedUpdaters(newUpdater.address);
        console.log("新更新者是否已授权:", isAuthorized);
        
        // 暂停合约
        console.log("暂停合约...");
        await oracle.pause();
        console.log("合约状态:", await oracle.paused() ? "已暂停" : "正常运行");
        
        // 恢复合约
        console.log("恢复合约...");
        await oracle.unpause();
        console.log("合约状态:", await oracle.paused() ? "已暂停" : "正常运行");
        
        // 紧急更新价格
        const emergencyPrice = ethers.utils.parseEther("2.0"); // 2 ETH
        console.log("紧急更新价格到:", ethers.utils.formatEther(emergencyPrice), "ETH");
        await oracle.emergencyUpdatePrice(emergencyPrice);
        
        const finalPrice = await oracle.getLatestPrice();
        console.log("最终价格:", ethers.utils.formatEther(finalPrice), "ETH");
        
        console.log("\n✅ 所有功能验证完成！");
        
    } catch (error) {
        console.error("❌ 测试过程中出现错误:", error.message);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 