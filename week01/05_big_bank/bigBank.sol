// 在 Bank 合约基础之上，编写 IBank 接口及BigBank 合约，使其满足 Bank 实现 IBank， BigBank 继承自 Bank ， 同时 BigBank 有附加要求：
// 要求存款金额 >0.001 ether（用modifier权限控制）
// BigBank 合约支持转移管理
// 编写一个 Admin 合约， Admin 合约有自己的 Owner ，同时有一个取款函数 adminWithdraw(IBank bank) , adminWithdraw 中会调用 IBank 接口的 withdraw 方法从而把 bank 合约内的资金转移到 Admin 合约地址。
// BigBank 和 Admin 合约 部署后，把 BigBank 的管理员转移给 Admin 合约地址，模拟几个用户的存款，然后
// Admin 合约的Owner地址调用 adminWithdraw(IBank bank) 把 BigBank 的资金转移到 Admin 地址。

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBank {
    function withdraw() external ;
}

contract Bank {
    mapping(address => uint256) public balances;
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin {
        require (msg.sender == admin, "You don't have permission");
        _;
    }

    function withdraw() external onlyAdmin{
        (bool success, ) = payable(admin).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}

contract BigBank is Bank{
    modifier depositLimit{
        require (msg.value >0.001 ether,"must greater than 0.001 ether");
        _;
    }
    receive() external payable depositLimit{ 
        balances[msg.sender] += msg.value;
    }  

    function trasferAdmin (address newAdmin) public onlyAdmin{
        admin = newAdmin;
    }
}

// Admin
contract Admin {
    address public owner;

    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
         require (msg.sender == owner, "You don't have Admin permission"); 
         _;
    }

    function adminWithdraw(IBank bank) public onlyOwner{
        bank.withdraw();
    }

}
