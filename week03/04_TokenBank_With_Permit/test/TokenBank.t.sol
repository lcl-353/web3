// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenBank_SupportPermit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20, ERC20Permit {
    constructor() ERC20("TestToken", "TTK") ERC20Permit("TestToken") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract TokenBankTest is Test {
    TokenBank public bank;
    TestToken public token;
    address user;

    function setUp() public {
        token = new TestToken();
        bank = new TokenBank(address(token), address(0)); // 使用零地址让合约使用默认 Permit2 地址
        user = address(0x1234);
        token.transfer(user, 1000 ether);
        vm.prank(user);
        token.approve(address(bank), 1000 ether);
    }

    function testDeposit() public {
        vm.prank(user);
        bank.deposit(100 ether);
        assertEq(bank.balances(user), 100 ether);
    }

    function testWithdraw() public {
        vm.startPrank(user);
        bank.deposit(200 ether);
        bank.withdraw(50 ether);
        assertEq(bank.balances(user), 150 ether);
        vm.stopPrank();
    }

    function testPermitDeposit() public {
        uint256 privateKey = 0x1234;
        address testUser = vm.addr(privateKey);
        
        uint256 amount = 300 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(testUser);
        
        // 使用代币合约的domainSeparator
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        
        // 构造permit的消息数据
        bytes32 permit = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            testUser,
            address(bank),
            amount,
            nonce,
            deadline
        ));
        
        // 计算最终要签名的消息
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            permit
        ));
        
        // 使用私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        // 确保用户有足够的代币
        vm.prank(address(this));
        token.transfer(testUser, amount);
        
        // 调用permitDeposit
        vm.prank(testUser);
        bank.permitDeposit(testUser, amount, deadline, v, r, s);
        
        // 验证结果
        assertEq(bank.balances(testUser), amount, "Deposit amount incorrect");
        assertEq(token.balanceOf(address(bank)), amount, "Bank balance incorrect");
    }

    function testPermitDepositWithExpiredDeadline() public {
        uint256 amount = 300 ether;
        uint256 nonce = token.nonces(user);
        uint256 deadline = block.timestamp - 1 hours; // 过期的deadline
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            0x1234,
            keccak256(abi.encodePacked(
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
            ))
        );
        
        vm.prank(user);
        vm.expectRevert("Permit expired");
        bank.permitDeposit(user, amount, deadline, v, r, s);
    }

    function testPermitDepositWithInvalidSignature() public {
        uint256 amount = 300 ether;
        uint256 nonce = token.nonces(user);
        uint256 deadline = block.timestamp + 1 hours;
        
        // 使用错误的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            0x5678, // 错误的私钥
            keccak256(abi.encodePacked(
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
            ))
        );
        
        vm.prank(user);
        vm.expectRevert("Invalid signature");
        bank.permitDeposit(user, amount, deadline, v, r, s);
    }

    function testPermitDepositReplayAttack() public {
        uint256 amount = 300 ether;
        uint256 nonce = token.nonces(user);
        uint256 deadline = block.timestamp + 1 hours;
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            0x1234,
            keccak256(abi.encodePacked(
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
            ))
        );
        
        // 第一次存款成功
        vm.prank(user);
        bank.permitDeposit(user, amount, deadline, v, r, s);
        
        // 尝试重放攻击（使用相同的签名再次存款）
        vm.prank(user);
        vm.expectRevert(); // 应该失败，因为nonce已经增加
        bank.permitDeposit(user, amount, deadline, v, r, s);
    }
}
