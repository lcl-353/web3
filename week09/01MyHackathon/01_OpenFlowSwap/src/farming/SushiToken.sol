// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title SushiToken
/// @notice The native governance token of the SushiSwap protocol with voting capabilities
contract SushiToken is ERC20, ERC20Votes, Ownable {
    uint256 private constant MAX_SUPPLY = 250_000_000 * 10**18; // 250 million tokens

    constructor() 
        ERC20("SushiToken", "SUSHI") 
        EIP712("SushiToken", "1")
        Ownable(msg.sender) 
    {
        // Initial supply is 0, tokens are minted through farming
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        require(totalSupply() + _amount <= MAX_SUPPLY, "SushiToken: cap exceeded");
        _mint(_to, _amount);
    }

    /// @notice Burns `_amount` token from `_account`. Must only be called by the owner.
    function burn(address _account, uint256 _amount) public onlyOwner {
        _burn(_account, _amount);
    }

    /// @notice Returns the clock mode for voting
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @notice Returns the clock mode description
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // Overrides required by Solidity for multiple inheritance
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }
} 