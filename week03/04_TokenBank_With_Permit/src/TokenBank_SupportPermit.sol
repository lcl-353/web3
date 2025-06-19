// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

// 添加 Permit2 相关的 import
interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function nonceBitmap(address, uint256) external view returns (uint256);
}

contract TokenBank is EIP712 {
    IERC20 public token;
    IPermit2 public immutable permit2;
    mapping(address => uint256) public balances;
    
    // 事件定义
    event Deposit(address indexed user, uint256 amount);

    // EIP-2612 的 permit 签名类型哈希
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // Permit2 合约地址 (主网和大多数测试网的地址)
    address constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    constructor(address _token, address _permit2) EIP712("TestToken", "1") {
        token = IERC20(_token);
        // 如果 _permit2 是零地址，使用默认的 Permit2 地址
        permit2 = IPermit2(_permit2 == address(0) ? PERMIT2_ADDRESS : _permit2);
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

    // 新增 depositWithPermit2 函数 - 使用 Permit2 进行签名授权转账
    function depositWithPermit2(
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(amount > 0, "Amount must be greater than 0");
        require(block.timestamp <= deadline, "Permit expired");

        // 构造 PermitTransferFrom 结构体
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: address(token), // 要授权的代币地址
                amount: amount  // 要授权的金额
            }),
            nonce: nonce, // 防止重放攻击的随机数
            deadline: deadline // 授权的截止时间
        });
        
        // 构造 SignatureTransferDetails 结构体
        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: address(this), // 接收代币的地址（当前合约）
            requestedAmount: amount // 请求转账的金额
        });

        // 使用 Permit2 的 permitTransferFrom 进行授权和转账
        permit2.permitTransferFrom(
            permit,
            transferDetails,
            msg.sender,     
            signature
        );
        
        // 执行存款逻辑
        _deposit(msg.sender, amount);
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
        emit Deposit(user, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdraw amount must greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }
}