// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFT_Market_Optimized.sol";
// import "../src/NFT_Market_and_ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// 简单的ERC721 Mock
contract ERC721Mock is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NFTMarketTest is Test {
    BaseERC20 token;
    ERC721Mock nft;
    NFTMarket market;
    address alice = address(0x1);
    address bob = address(0x2);
    uint256 tokenId = 1;
    uint96 price = 1e18;

    function setUp() public {
        token = new BaseERC20();
        nft = new ERC721Mock();
        market = new NFTMarket(address(token), address(nft));
        // 给alice和bob分配初始token
        token.transfer(alice, 1_000_000e18);
        token.transfer(bob, 1_000_000e18);
        // mint NFT 给alice
        nft.mint(alice, tokenId);
    }

    function testListAndBuyWithTransferWithCallback() public {
        vm.startPrank(alice);
        // alice approve NFT
        nft.approve(address(market), tokenId);
        // alice 上架NFT
        market.list(tokenId, price);
        vm.stopPrank();

        // bob approve market合约花费token
        vm.startPrank(bob);
        token.approve(address(market), price);
        // bob 用transferWithCallback购买NFT
        token.transferWithCallback(address(market), price, tokenId);
        // bob获得NFT
        assertEq(nft.ownerOf(tokenId), bob);
        // alice收到钱
        assertEq(token.balanceOf(alice), 1_000_000e18 + price);
        // bob扣钱
        assertEq(token.balanceOf(bob), 1_000_000e18 - price);
        vm.stopPrank();
    }

    function testListAndBuyWithBuyNFT() public {
        vm.startPrank(alice);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(market), price);
        market.buyNFT(tokenId);
        assertEq(nft.ownerOf(tokenId), bob);
        assertEq(token.balanceOf(alice), 1_000_000e18 + price);
        assertEq(token.balanceOf(bob), 1_000_000e18 - price);
        vm.stopPrank();
    }

    function testListRevertIfNotOwner() public {
        vm.startPrank(bob);
        vm.expectRevert();
        market.list(tokenId, price);
        vm.stopPrank();
    }

    function testBuyRevertIfNotListed() public {
        vm.startPrank(bob);
        vm.expectRevert();
        market.buyNFT(tokenId);
        vm.stopPrank();
    }

    function testBuyRevertIfWrongPrice() public {
        vm.startPrank(alice);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(market), price - 1);
        vm.expectRevert();
        token.transferWithCallback(address(market), price - 1, tokenId);
        vm.stopPrank();
    }

    function testListAndBuyNFT100Times() public {
        uint96 _price = price;
        for (uint256 i = 0; i < 100; i++) {
            // mint新NFT给alice
            uint256 _tokenId = i + 1000; // 避免与其他测试冲突
            vm.startPrank(alice);
            nft.mint(alice, _tokenId);
            nft.approve(address(market), _tokenId);
            market.list(_tokenId, _price);
            vm.stopPrank();

            vm.startPrank(bob);
            token.approve(address(market), _price);
            market.buyNFT(_tokenId);
            assertEq(nft.ownerOf(_tokenId), bob);
            vm.stopPrank();
        }
    }
}
