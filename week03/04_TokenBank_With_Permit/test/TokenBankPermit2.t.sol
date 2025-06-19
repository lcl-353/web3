// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenBank_SupportPermit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 创建一个支持 Permit 的测试代币
contract TestToken is ERC20, ERC20Permit {
    constructor() ERC20("TestToken", "TTK") ERC20Permit("TestToken") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

// Mock Permit2 合约用于测试
contract MockPermit2 {
    // 存储 nonce bitmap
    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;
    
    // EIP-712 domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;
    
    // Type hashes
    bytes32 private constant _TOKEN_PERMISSIONS_TYPEHASH = 
        keccak256("TokenPermissions(address token,uint256 amount)");
    
    bytes32 private constant _PERMIT_TRANSFER_FROM_TYPEHASH = 
        keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)");

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Permit2")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

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
        bytes memory signature
    ) external {
        require(block.timestamp <= permit.deadline, "Permit2: deadline expired");
        
        // 验证 nonce
        uint256 wordPos = permit.nonce >> 8;
        uint256 bitPos = permit.nonce & 0xff;
        uint256 word = nonceBitmap[owner][wordPos];
        require(((word >> bitPos) & 1) == 0, "Permit2: nonce already used");
        
        // 标记 nonce 为已使用
        nonceBitmap[owner][wordPos] = word | (1 << bitPos);
        
        // 验证签名
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount)
        );
        
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TRANSFER_FROM_TYPEHASH,
                tokenPermissionsHash,
                msg.sender,
                permit.nonce,
                permit.deadline
            )
        );
        
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        
        // 解析签名 - 使用简化的方法
        require(signature.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        
        address signer = ecrecover(digest, v, r, s);
        require(signer == owner, "Permit2: invalid signature");
        require(transferDetails.requestedAmount <= permit.permitted.amount, "Permit2: amount exceeds permitted");
        
        // 执行转账
        IERC20(permit.permitted.token).transferFrom(
            owner, 
            transferDetails.to, 
            transferDetails.requestedAmount
        );
    }
}

contract TokenBankPermit2Test is Test {
    TokenBank public bank;
    TestToken public token;
    MockPermit2 public permit2;
    
    address public user;
    uint256 public userPrivateKey;
    
    event Deposit(address indexed user, uint256 amount);

    function setUp() public {
        // 部署合约
        token = new TestToken();
        permit2 = new MockPermit2();
        
        // 使用带 permit2 地址的构造函数
        bank = new TokenBank(address(token), address(permit2));
        
        // 设置测试用户
        userPrivateKey = 0x1234;
        user = vm.addr(userPrivateKey);
        
        // 给用户转一些代币
        token.transfer(user, 10000 ether);
        
        // 用户需要先授权 permit2 合约
        vm.prank(user);
        token.approve(address(permit2), type(uint256).max);
    }

    function testDepositWithPermit2() public {
        uint256 depositAmount = 1000 ether;
        uint256 nonce = 0; // 第一个 nonce
        uint256 deadline = block.timestamp + 1 hours;
        
        // 创建签名
        bytes memory signature = _createPermit2Signature(
            address(token),
            depositAmount,
            nonce,
            deadline,
            userPrivateKey
        );
        
        // 记录初始状态
        uint256 initialUserBalance = token.balanceOf(user);
        uint256 initialBankBalance = token.balanceOf(address(bank));
        uint256 initialUserDeposits = bank.balances(user);
        
        // 期待触发 Deposit 事件
        vm.expectEmit(true, false, false, true);
        emit Deposit(user, depositAmount);
        
        // 执行 depositWithPermit2
        vm.prank(user);
        bank.depositWithPermit2(depositAmount, nonce, deadline, signature);
        
        // 验证状态变化
        assertEq(token.balanceOf(user), initialUserBalance - depositAmount, "User token balance incorrect");
        assertEq(token.balanceOf(address(bank)), initialBankBalance + depositAmount, "Bank token balance incorrect");
        assertEq(bank.balances(user), initialUserDeposits + depositAmount, "User deposit balance incorrect");
    }

    function testDepositWithPermit2ExpiredDeadline() public {
        uint256 depositAmount = 1000 ether;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp - 1; // 过期的 deadline
        
        bytes memory signature = _createPermit2Signature(
            address(token),
            depositAmount,
            nonce,
            deadline,
            userPrivateKey
        );
        
        vm.prank(user);
        vm.expectRevert("Permit expired");
        bank.depositWithPermit2(depositAmount, nonce, deadline, signature);
    }

    function testDepositWithPermit2ZeroAmount() public {
        uint256 depositAmount = 0;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes memory signature = _createPermit2Signature(
            address(token),
            depositAmount,
            nonce,
            deadline,
            userPrivateKey
        );
        
        vm.prank(user);
        vm.expectRevert("Amount must be greater than 0");
        bank.depositWithPermit2(depositAmount, nonce, deadline, signature);
    }

    function testDepositWithPermit2NonceReuse() public {
        uint256 depositAmount = 1000 ether;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes memory signature = _createPermit2Signature(
            address(token),
            depositAmount,
            nonce,
            deadline,
            userPrivateKey
        );
        
        // 第一次存款应该成功
        vm.prank(user);
        bank.depositWithPermit2(depositAmount, nonce, deadline, signature);
        
        // 尝试重用相同的 nonce 应该失败
        vm.prank(user);
        vm.expectRevert("Permit2: nonce already used");
        bank.depositWithPermit2(depositAmount, nonce, deadline, signature);
    }

    function testDepositWithPermit2InvalidSignature() public {
        uint256 depositAmount = 1000 ether;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 使用错误的私钥创建签名
        bytes memory invalidSignature = _createPermit2Signature(
            address(token),
            depositAmount,
            nonce,
            deadline,
            0x5678 // 错误的私钥
        );
        
        vm.prank(user);
        vm.expectRevert("Permit2: invalid signature");
        bank.depositWithPermit2(depositAmount, nonce, deadline, invalidSignature);
    }

    function testDepositWithPermit2MultipleDeposits() public {
        uint256 firstAmount = 500 ether;
        uint256 secondAmount = 300 ether;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 第一次存款
        bytes memory signature1 = _createPermit2Signature(
            address(token),
            firstAmount,
            0, // nonce 0
            deadline,
            userPrivateKey
        );
        
        vm.prank(user);
        bank.depositWithPermit2(firstAmount, 0, deadline, signature1);
        
        // 第二次存款（使用不同的 nonce）
        bytes memory signature2 = _createPermit2Signature(
            address(token),
            secondAmount,
            1, // nonce 1
            deadline,
            userPrivateKey
        );
        
        vm.prank(user);
        bank.depositWithPermit2(secondAmount, 1, deadline, signature2);
        
        // 验证总存款
        assertEq(bank.balances(user), firstAmount + secondAmount, "Total deposits incorrect");
    }

    // 辅助函数：创建 Permit2 签名
    function _createPermit2Signature(
        address tokenAddress,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        // 构造 TokenPermissions hash
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                tokenAddress,
                amount
            )
        );
        
        // 构造 PermitTransferFrom hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"),
                tokenPermissionsHash,
                address(bank),
                nonce,
                deadline
            )
        );
        
        // 构造最终的 digest
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), structHash)
        );
        
        // 签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // 返回打包的签名
        return abi.encodePacked(r, s, v);
    }

    // 测试基础存款功能（确保合约其他功能正常）
    function testBasicDeposit() public {
        uint256 amount = 500 ether;
        
        vm.startPrank(user);
        token.approve(address(bank), amount);
        bank.deposit(amount);
        vm.stopPrank();
        
        assertEq(bank.balances(user), amount, "Basic deposit failed");
    }

    // 测试提取功能
    function testWithdraw() public {
        uint256 depositAmount = 1000 ether;
        uint256 withdrawAmount = 300 ether;
        
        // 先通过 permit2 存款
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _createPermit2Signature(
            address(token),
            depositAmount,
            nonce,
            deadline,
            userPrivateKey
        );
        
        vm.prank(user);
        bank.depositWithPermit2(depositAmount, nonce, deadline, signature);
        
        // 然后提取部分资金
        uint256 initialBalance = token.balanceOf(user);
        
        vm.prank(user);
        bank.withdraw(withdrawAmount);
        
        assertEq(bank.balances(user), depositAmount - withdrawAmount, "Withdraw balance incorrect");
        assertEq(token.balanceOf(user), initialBalance + withdrawAmount, "Withdraw token balance incorrect");
    }

    // 测试 permitDeposit 功能（确保现有功能不被破坏）
    function testPermitDeposit() public {
        uint256 amount = 500 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user);
        
        // 构造 permit 签名
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    user,
                    address(bank),
                    amount,
                    nonce,
                    deadline
                ))
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        
        vm.prank(user);
        bank.permitDeposit(user, amount, deadline, v, r, s);
        
        assertEq(bank.balances(user), amount, "Permit deposit failed");
    }
} 