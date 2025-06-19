// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract TokenBank is EIP712 {
    IERC20 public token;
    mapping(address => uint256) public balances;

    // EIP-2612 的 permit 签名类型哈希
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    constructor(address _token) EIP712("TestToken", "1") {  // 修改domain name与代币一致
        token = IERC20(_token);
    }

    // 新增 permitDeposit 函数
    function permitDeposit(
        address owner,     // 代币持有者
        uint256 amount,    // 存款金额
        uint256 deadline,  // 签名有效期截止时间
        uint8 v, bytes32 r, bytes32 s  // 签名分量
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        // 直接调用代币合约的permit方法，不再自己验证签名
        IERC20Permit(address(token)).permit(owner, address(this), amount, deadline, v, r, s);
        
        // 执行转账和存款
        require(token.transferFrom(owner, address(this), amount), "Transfer failed");
        _deposit(owner, amount);
    }

    // 原有存款函数（可选：保留传统存款方式）
    function deposit(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        _deposit(msg.sender, amount);
    }

    // 内部存款逻辑复用
    function _deposit(address user, uint256 amount) private {
        require(amount > 0, "Deposit amount must be greater than 0");
        balances[user] += amount;
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdraw amount must greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }
}