// 1. 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
// 2. 在 Bank 合约记录每个地址的存款金额
// 3. 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
// 4. 用数组记录存款金额的前 3 名用户

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Bank {
    mapping (address => uint256) balances;
    address public admin;

    address[3] public topDepositors;

    constructor(address owner) {
        admin = owner;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        updateTopDepositors(msg.sender);
    }

    function getTopDepositors() public view returns (address[3] memory) {
        return topDepositors;
    }
    
    function getBalance(address _account) public view returns (uint256) {
        return balances[_account];
    }

    function withdraw()  public {
        require(msg.sender == admin, "You don't have permission");
        
        payable(msg.sender).transfer(address(this).balance);
    }

    // array save top 3 depositors
    function updateTopDepositors(address depositor) internal {

        // 若用户已在榜单中，无需扩容，仅重新排序
        for (uint i = 0; i < 3; i++) {
            if (topDepositors[i] == depositor) {
                sortTopDepositors();
                return;
            }
        }
        // 若未在榜单且其余额超过当前第 3 名，则替换并排序
        if (balances[depositor] > balances[topDepositors[2]]) {
            topDepositors[2] = depositor;
            sortTopDepositors();
        }
    }

    // bubble sort top3
    function sortTopDepositors() internal {

        uint len = topDepositors.length;               // 固定长度为 3
        bool swapped;
        // 外层循环 O(n)
        for (uint i = 0; i < len - 1; i++) {           // 冒泡排序外层循环
            swapped = false;
            // 内层循环 O(n-i-1)
            for (uint j = 0; j < len - i - 1; j++) {
                // 比较相邻两位的存款余额，较大者前置
                if (balances[topDepositors[j]] < balances[topDepositors[j + 1]]) {
                    // 原地交换地址，无需临时结构体
                    (topDepositors[j], topDepositors[j + 1]) = 
                        (topDepositors[j + 1], topDepositors[j]);          // tuple 赋值交换
                    swapped = true;
                }
            }
            if (!swapped) {
                break;  // 若一轮无交换，说明已完成排序，提前退出
            }
        }
    }
}
