// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.5.16;

import "./utils/DSTest.sol";
import "../src/UniswapV2Factory.sol";
import "./mocks/ERC20Mock.sol";

contract UniswapV2FactoryTest is DSTest {
    UniswapV2Factory factory;
    ERC20Mock tokenA;
    ERC20Mock tokenB;
    address feeToSetter;

    function setUp() public {
        feeToSetter = address(this);
        factory = new UniswapV2Factory(feeToSetter);
        
        // Deploy two mock tokens for testing
        tokenA = new ERC20Mock("Token A", "TKNA");
        tokenB = new ERC20Mock("Token B", "TKNB");
    }

    function testCreatePair() public {
        address pair = factory.createPair(address(tokenA), address(tokenB));
        
        assertTrue(pair != address(0), "Pair address should not be zero");
        assertTrue(factory.getPair(address(tokenA), address(tokenB)) == pair, "getPair should return correct address");
        assertTrue(factory.getPair(address(tokenB), address(tokenA)) == pair, "getPair reverse should return same address");
        assertTrue(factory.allPairsLength() == 1, "allPairs length should be 1");
    }

    function testCannotCreatePairWithIdenticalTokens() public {
        // This should revert
        factory.createPair(address(tokenA), address(tokenA));
        // If we reach here, the test should fail because the transaction should have reverted
        assertTrue(false, "Should not be able to create pair with identical tokens");
    }

    function testCannotCreatePairWithZeroAddress() public {
        factory.createPair(address(0), address(tokenA));
        // If we reach here, the test should fail because the transaction should have reverted
        assertTrue(false, "Should not be able to create pair with zero address");
    }

    function testCannotCreateDuplicatePair() public {
        factory.createPair(address(tokenA), address(tokenB));
        factory.createPair(address(tokenA), address(tokenB));
        // If we reach here, the test should fail because the transaction should have reverted
        assertTrue(false, "Should not be able to create duplicate pair");
    }

    function testSetFeeTo() public {
        address newFeeTo = address(0x123);
        factory.setFeeTo(newFeeTo);
        assertTrue(factory.feeTo() == newFeeTo, "feeTo should be updated");
    }

    function testSetFeeToSetter() public {
        address newFeeToSetter = address(0x456);
        factory.setFeeToSetter(newFeeToSetter);
        assertTrue(factory.feeToSetter() == newFeeToSetter, "feeToSetter should be updated");
    }

    function testCannotSetFeeToWithoutPermission() public {
        // Create a new contract to act as a different address
        FeeToSetterCaller caller = new FeeToSetterCaller(factory);
        caller.trySetFeeTo(address(0x123));
        // If we reach here, the test should fail because the transaction should have reverted
        assertTrue(false, "Should not be able to set feeTo without permission");
    }

    function testCannotSetFeeToSetterWithoutPermission() public {
        // Create a new contract to act as a different address
        FeeToSetterCaller caller = new FeeToSetterCaller(factory);
        caller.trySetFeeToSetter(address(0x456));
        // If we reach here, the test should fail because the transaction should have reverted
        assertTrue(false, "Should not be able to set feeToSetter without permission");
    }
}

// Helper contract to test permissions
contract FeeToSetterCaller {
    UniswapV2Factory factory;
    
    constructor(UniswapV2Factory _factory) public {
        factory = _factory;
    }
    
    function trySetFeeTo(address _feeTo) public {
        factory.setFeeTo(_feeTo);
    }
    
    function trySetFeeToSetter(address _feeToSetter) public {
        factory.setFeeToSetter(_feeToSetter);
    }
}
