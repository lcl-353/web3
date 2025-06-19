// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFT_Market_Permit.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock NFT contract for testing
contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract NFTMarketPermitTest is Test {
    NFTMarket market;
    MockNFT nft;
    MockERC20 token;
    
    uint256 projectSignerPrivateKey;
    address projectSigner;
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    
    uint256 constant PRICE = 100 ether;
    uint256 constant TOKEN_ID = 1;
    
    function setUp() public {
        // Setup project signer
        projectSignerPrivateKey = 0x12345; // 使用一个固定的私钥
        projectSigner = vm.addr(projectSignerPrivateKey);

        // Deploy contracts
        nft = new MockNFT();
        token = new MockERC20();
        market = new NFTMarket(projectSigner);
        
        // Setup initial token distribution
        token.transfer(buyer, 1000 ether);
        
        // Mint NFT to seller
        nft.mint(seller, TOKEN_ID);
    }

    function testList() public {
        // Setup NFT approval
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID);
        
        // List NFT
        market.list(
            address(nft),
            TOKEN_ID,
            PRICE,
            address(token)
        );
        vm.stopPrank();
        
        // Verify listing
        (
            address lSeller,
            address lNftContract,
            uint256 lTokenId,
            uint256 lPrice,
            address lPaymentToken,
            bool lIsActive
        ) = market.listings(address(nft), TOKEN_ID);
        
        assertEq(lSeller, seller);
        assertEq(lNftContract, address(nft));
        assertEq(lTokenId, TOKEN_ID);
        assertEq(lPrice, PRICE);
        assertEq(lPaymentToken, address(token));
        assertTrue(lIsActive);
    }

    function testPurchase() public {
        // First list the NFT
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID);
        market.list(address(nft), TOKEN_ID, PRICE, address(token));
        vm.stopPrank();

        // Buyer purchases NFT
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.purchase(address(nft), TOKEN_ID);
        vm.stopPrank();

        // Verify purchase
        assertEq(nft.ownerOf(TOKEN_ID), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        
        (
            ,
            ,
            ,
            ,
            ,
            bool lIsActive
        ) = market.listings(address(nft), TOKEN_ID);
        assertFalse(lIsActive);
    }

    function testPermitBuy() public {
        // First list the NFT
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID);
        market.list(address(nft), TOKEN_ID, PRICE, address(token));
        vm.stopPrank();

        // Create permit mint data
        NFTMarket.Mint memory mint = NFTMarket.Mint({
            to: buyer,
            tokenId: TOKEN_ID
        });

        // Generate signature from project signer
        bytes32 digest = market.hashMint(mint);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            projectSignerPrivateKey,
            digest
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        console2.logBytes32(digest);
        console2.log("projectSigner's address:", projectSigner);
        console2.log("v:", v);
        console2.logBytes32(r);
        console2.logBytes32(s);
        // Buyer purchases NFT with permit
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.permitBuy(address(nft), TOKEN_ID, mint, signature);
        vm.stopPrank();

        // Verify purchase
        assertEq(nft.ownerOf(TOKEN_ID), buyer);
        assertEq(token.balanceOf(seller), PRICE);
        assertTrue(market.usedSignatures(signature));
        
        (
            ,
            ,
            ,
            ,
            ,
            bool lIsActive
        ) = market.listings(address(nft), TOKEN_ID);
        assertFalse(lIsActive);
    }

    function test_RevertWhen_PermitBuyWithInvalidSignature() public {
        // First list the NFT
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID);
        market.list(address(nft), TOKEN_ID, PRICE, address(token));
        vm.stopPrank();

        // Create permit mint data
        NFTMarket.Mint memory mint = NFTMarket.Mint({
            to: buyer,
            tokenId: TOKEN_ID
        });

        // Generate invalid signature (using wrong signer)
        bytes32 digest = market.hashMint(mint);
        uint256 wrongPrivateKey = uint256(keccak256(abi.encodePacked("wrong signer")));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempt to purchase with invalid signature (should fail)
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectRevert("Invalid signature");
        market.permitBuy(address(nft), TOKEN_ID, mint, signature);
    }

    function test_RevertWhen_PermitBuyWithUsedSignature() public {
        // First list the NFT
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID);
        market.list(address(nft), TOKEN_ID, PRICE, address(token));
        vm.stopPrank();

        // Create permit mint data
        NFTMarket.Mint memory mint = NFTMarket.Mint({
            to: buyer,
            tokenId: TOKEN_ID
        });

        // Generate valid signature
        bytes32 digest = market.hashMint(mint);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            projectSignerPrivateKey,
            digest
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        // First purchase with signature
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        market.permitBuy(address(nft), TOKEN_ID, mint, signature);
        vm.stopPrank();

        // List another NFT
        nft.mint(seller, TOKEN_ID + 1);
        vm.startPrank(seller);
        nft.approve(address(market), TOKEN_ID + 1);
        market.list(address(nft), TOKEN_ID + 1, PRICE, address(token));
        vm.stopPrank();

        // Attempt to reuse signature (should fail)
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        vm.expectRevert("Signature already used");
        market.permitBuy(address(nft), TOKEN_ID + 1, mint, signature);
    }
}
