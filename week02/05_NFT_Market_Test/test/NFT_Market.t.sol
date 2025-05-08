// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFT_Market.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC721 is ERC721 {
    uint256 public tokenId;

    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to) external returns (uint256) {
        tokenId += 1;
        _mint(to, tokenId);
        return tokenId;
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract NFTMarketTest is Test {
    NFTMarket public market;
    MockERC721 public nft;
    MockERC20 public token;

    address public seller = address(1);
    address public buyer = address(2);
    uint256 public tokenId;
    uint256 public price = 100 * 1e18;

    function setUp() public {
        market = new NFTMarket();
        nft = new MockERC721();
        token = new MockERC20();

        token.mint(buyer, 1000 * 1e18);
        vm.prank(seller);
        tokenId = nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(market), tokenId);
    }

    function testListSuccess() public {
        vm.prank(seller);
        market.list(address(nft), tokenId, address(token), price);

        (address listedSeller, address payToken, uint256 listedPrice) = market.listings(address(nft), tokenId);
        assertEq(listedSeller, seller);
        assertEq(payToken, address(token));
        assertEq(listedPrice, price);
    }

    function testListFailNotOwner() public {
        vm.prank(buyer);
        vm.expectRevert("Not the owner");
        market.list(address(nft), tokenId, address(token), price);
    }

    function testBuySuccess() public {
        vm.prank(seller);
        market.list(address(nft), tokenId, address(token), price);

        vm.prank(buyer);
        token.approve(address(market), price);
        vm.prank(buyer);
        market.buy(address(nft), tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
    }

    function testBuyFailNotListed() public {
        vm.prank(buyer);
        vm.expectRevert("Item not listed");
        market.buy(address(nft), tokenId);
    }

    function testBuyFailSelfPurchase() public {
        vm.prank(seller);
        market.list(address(nft), tokenId, address(token), price);

        vm.prank(seller);
        token.approve(address(market), price);
        vm.prank(seller);
        vm.expectRevert("Cannot buy your own NFT");
        market.buy(address(nft), tokenId);
    }

    function testBuyFailInsufficientFunds() public {
        vm.prank(seller);
        market.list(address(nft), tokenId, address(token), price);

        vm.prank(buyer);
        token.approve(address(market), price - 1);
        vm.prank(buyer);
        vm.expectRevert();
        market.buy(address(nft), tokenId);
    }

    function testFuzzListingAndBuying(uint256 _price) public {
        _price = bound(_price, 1e16, 1e22); // 0.01 to 10000 tokens

        vm.prank(buyer);
       token.mint(buyer, _price);

        vm.prank(seller);
        uint256 newTokenId = nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(market), newTokenId);
        vm.prank(seller);
        market.list(address(nft), newTokenId, address(token), _price);

        vm.prank(buyer);
        token.approve(address(market), _price);
        vm.prank(buyer);
        market.buy(address(nft), newTokenId);

        assertEq(nft.ownerOf(newTokenId), buyer);
    }

    function testMarketDoesNotHoldTokens() public {
        vm.prank(seller);
        market.list(address(nft), tokenId, address(token), price);

        vm.prank(buyer);
        token.approve(address(market), price);
        vm.prank(buyer);
        market.buy(address(nft), tokenId);

        assertEq(token.balanceOf(address(market)), 0);
    }
}
