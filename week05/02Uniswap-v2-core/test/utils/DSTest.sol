// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.5.16;

import "../../src/interfaces/IUniswapV2Factory.sol";

contract DSTest {
    event log                    (string);
    event logs                   (bytes);

    event log_address           (address);
    event log_bytes32           (bytes32);
    event log_int              (int);
    event log_uint             (uint);
    event log_bytes            (bytes);
    event log_string           (string);

    event log_named_address     (string key, address val);
    event log_named_bytes32     (string key, bytes32 val);
    event log_named_decimal_int (string key, int val, uint decimals);
    event log_named_decimal_uint(string key, uint val, uint decimals);
    event log_named_int        (string key, int val);
    event log_named_uint       (string key, uint val);
    event log_named_bytes      (string key, bytes val);
    event log_named_string     (string key, string val);

    bool public IS_TEST = true;
    bool public failed;

    function fail() internal {
        failed = true;
    }

    function assertTrue(bool condition) internal {
        if (!condition) {
            emit log("Error: Assertion Failed");
            fail();
        }
    }

    function assertTrue(bool condition, string memory err) internal {
        if (!condition) {
            emit log_named_string("Error", err);
            assertTrue(condition);
        }
    }

    function assertEq(address a, address b) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [address]");
            emit log_named_address("  Expected", b);
            emit log_named_address("    Actual", a);
            fail();
        }
    }

    function assertEq(uint a, uint b) internal {
        if (a != b) {
            emit log("Error: a == b not satisfied [uint]");
            emit log_named_uint("  Expected", b);
            emit log_named_uint("    Actual", a);
            fail();
        }
    }
}
