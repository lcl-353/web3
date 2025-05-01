// 1. 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
// 2. 在 Bank 合约记录每个地址的存款金额
// 3. 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
// 4. 用数组记录存款金额的前 3 名用户

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Bank {
    mapping (address => uint256) balances;
    address admin;

    struct TopDepositor {
        address user;
        uint256 amount;
    }

    TopDepositor[3] public topDepositors;

    constructor() {
        admin = msg.sender;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        updateTopDepositors(msg.sender);
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
        uint256 userBalance = balances[depositor];

        // check whether in list
        for (uint256 i = 0; i < 3; i++) {
            if (topDepositors[i].user == depositor) {
                topDepositors[i].amount = userBalance;
                sortTopDepositors();
                return;
            }
        }

        // if not in list, check whether let it in
        for (uint256 i = 0; i < 3; i++) {
            if (userBalance > topDepositors[i].amount) {
                topDepositors[2] = TopDepositor(depositor, userBalance);
                sortTopDepositors();
                break;
            }
        }
    }

    // select sort top3
    function sortTopDepositors() internal {
        for (uint256 i = 0; i < 2; i++) {
            for (uint256 j = i + 1; j < 3; j++) {
                if (topDepositors[j].amount > topDepositors[i].amount) {
                    TopDepositor memory temp = topDepositors[i];
                    topDepositors[i] = topDepositors[j];
                    topDepositors[j] = temp;
                }
            }
        }
    }
        
    // function deposit() external payable {
    //     balances_[msg.sender] += msg.value;
    // }
}

