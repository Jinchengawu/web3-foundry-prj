pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {Bank} from "../../../src/W1/D3/Bank.sol";


/***


测试Case 包含：

断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
检查存款金额的前 3 名用户是否正确，分别检查有1个、2个、3个、4 个用户， 以及同一个用户多次存款的情况。
检查只有管理员可取款，其他人不可以取款。

 */
contract BankTest is Test {
    Bank public bank;

    function setUp() public {
        bank = new Bank();
    }

    function testDeposit() public {
        bank.deposit{value: 1 ether}();
        assertEq(bank.balances(address(this)), 1 ether);
    }

    function testWithdraw() public {
        // 先存款 1 ether
        bank.deposit{value: 1 ether}();
        // 记录取款前的余额
        uint256 balanceBefore = address(this).balance;
        // 取款 1 ether
        bank.withdraw(address(this), 1 ether);
        // 检查余额增加了 1 ether
        assertEq(address(this).balance, balanceBefore + 1 ether);
        console2.log("balanceBefore", balanceBefore);
    }

    function testChangeOwner() public {
        bank.changeOwner(address(this));
        assertEq(bank.owner(), address(this));
    }

    // 添加 receive 函数来接收 ETH
    receive() external payable {}
}

/**
验证日志：
zhuizhui@zhuizhuideMacBook-Pro web3-foundry-prj % forge test test/W2/D4/Bank.t.sol -vvvv
[⠊] Compiling...
No files changed, compilation skipped

Ran 3 tests for test/W2/D4/Bank.t.sol:BankTest
[PASS] testChangeOwner() (gas: 12840)
Traces:
  [12840] BankTest::testChangeOwner()
    ├─ [2918] Bank::changeOwner(BankTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   └─ ← [Stop]
    ├─ [553] Bank::owner() [staticcall]
    │   └─ ← [Return] BankTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496]
    ├─ [0] VM::assertEq(BankTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], BankTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496]) [staticcall]
    │   └─ ← [Return]
    └─ ← [Stop]

[PASS] testDeposit() (gas: 69215)
Traces:
  [69215] BankTest::testDeposit()
    ├─ [52436] Bank::deposit{value: 1000000000000000000}()
    │   └─ ← [Stop]
    ├─ [824] Bank::balances(BankTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496]) [staticcall]
    │   └─ ← [Return] 1000000000000000000 [1e18]
    ├─ [0] VM::assertEq(1000000000000000000 [1e18], 1000000000000000000 [1e18]) [staticcall]
    │   └─ ← [Return]
    └─ ← [Stop]

[PASS] testWithdraw() (gas: 80680)
Traces:
  [80680] BankTest::testWithdraw()
    ├─ [52436] Bank::deposit{value: 1000000000000000000}()
    │   └─ ← [Stop]
    ├─ [12067] Bank::withdraw(BankTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], 1000000000000000000 [1e18])
    │   ├─ [55] BankTest::receive{value: 1000000000000000000}()
    │   │   └─ ← [Stop]
    │   └─ ← [Stop]
    ├─ [0] VM::assertEq(79228162514264337593543950335 [7.922e28], 79228162514264337593543950335 [7.922e28]) [staticcall]
    │   └─ ← [Return]
    └─ ← [Stop]

Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 1.54ms (1.00ms CPU time)

Ran 1 test suite in 325.96ms (1.54ms CPU time): 3 tests passed, 0 failed, 0 skipped (3 total tests)


 */