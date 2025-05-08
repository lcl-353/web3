// test/Bank.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    Bank bank;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    address user4 = address(0x4);

    function setUp() public {
        bank = new Bank(address(this));
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
    }

    function testDepositBalanceUpdates() public {
        vm.prank(user1);
        address(bank).call{value: 1 ether}("");
        assertEq(bank.getBalance(user1), 1 ether);

        vm.prank(user1);
        address(bank).call{value: 2 ether}("");
        assertEq(bank.getBalance(user1), 3 ether);
    }

    function testTopDepositorsWithOneUser() public {
        vm.prank(user1);
        address(bank).call{value: 5 ether}("");
        address[3] memory tops = bank.getTopDepositors();
        assertEq(tops[0], user1);
        assertEq(tops[1], address(0));
        assertEq(tops[2], address(0));
    }

    function testTopDepositorsWithTwoUsers() public {
        vm.prank(user1);
        address(bank).call{value: 5 ether}("");
        vm.prank(user2);
        address(bank).call{value: 3 ether}("");

        address[3] memory tops = bank.getTopDepositors();
        assertEq(tops[0], user1);
        assertEq(tops[1], user2);
        assertEq(tops[2], address(0));
    }

    function testTopDepositorsWithThreeUsers() public {
        vm.prank(user1);
        address(bank).call{value: 5 ether}("");
        vm.prank(user2);
        address(bank).call{value: 3 ether}("");
        vm.prank(user3);
        address(bank).call{value: 7 ether}("");

        address[3] memory tops = bank.getTopDepositors();
        assertEq(tops[0], user3);
        assertEq(tops[1], user1);
        assertEq(tops[2], user2);
    }

    function testTopDepositorsWithFourUsers() public {
        vm.prank(user1); address(bank).call{value: 5 ether}("");
        vm.prank(user2); address(bank).call{value: 3 ether}("");
        vm.prank(user3); address(bank).call{value: 7 ether}("");
        vm.prank(user4); address(bank).call{value: 4 ether}("");

        address[3] memory tops = bank.getTopDepositors();
        assertEq(tops[0], user3);
        assertEq(tops[1], user1);
        assertEq(tops[2], user4);
    }

    function testTopDepositorMultipleDeposits() public {
        vm.prank(user2);
        address(bank).call{value: 2 ether}("");
        vm.prank(user2);
        address(bank).call{value: 6 ether}("");
        vm.prank(user1);
        address(bank).call{value: 5 ether}("");
        vm.prank(user3);
        address(bank).call{value: 1 ether}("");

        address[3] memory tops = bank.getTopDepositors();
        assertEq(tops[0], user2);
        assertEq(tops[1], user1);
        assertEq(tops[2], user3);
    }

    function testAdminCanWithdraw() public {
        vm.prank(user1); address(bank).call{value: 2 ether}("");
        vm.prank(user2); address(bank).call{value: 3 ether}("");
        assertEq(address(bank).balance, 5 ether);

        address adminAddr = bank.admin();
        address thisC = address(this);
        console.log("Value of adminAddr:", adminAddr);
        console.log("Value of thisC:", thisC);

        uint256 before = address(this).balance;
        bank.withdraw();
        assertEq(address(bank).balance, 0);
        assertEq(address(this).balance, before + 5 ether);
    }

    function testNonAdminCannotWithdraw() public {
        vm.prank(user1);
        address(bank).call{value: 1 ether}("");

        vm.prank(user1);
        vm.expectRevert("You don't have permission");
        bank.withdraw();
    }

    receive() external payable {
        
    }
}
