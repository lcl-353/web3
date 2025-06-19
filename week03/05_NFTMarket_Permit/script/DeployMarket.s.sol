// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/ERC721.sol";
import "../src/ERC20.sol";
import "../src/NFT_Market_Permit.sol";

contract DeployMarket is Script {
    function setUp() public {}

    function run() external {
        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // 设置项目签名者为部署者
        address projectSigner = deployer;
        
        console.log("=== Deployment Configuration ===");
        console.log("Deployer:", deployer);
        console.log("Project Signer:", projectSigner);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 MockERC20
        MockERC20 token = new MockERC20();
        console.log("\n=== MockERC20 deployed ===");
        console.log("Address:", address(token));

        // 2. 部署 MockNFT
        MyNFT nft = new MyNFT();
        
        console.log("\n=== MockNFT deployed ===");
        console.log("Address:", address(nft));

        // 3. 部署 NFTMarket
        NFTMarket market = new NFTMarket(projectSigner);
        console.log("\n=== NFTMarket deployed ===");
        console.log("Address:", address(market));
        
        // 4. 设置 MockNFT 的批准
        // nft.mint(deployer); // Mint an NFT to the deployer
        // nft.mint(deployer); // Mint another NFT to the deployer
        // nft.approve(address(market), 0);
        // nft.approve(address(market), 1);


        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("MockERC20:  ", address(token));
        console.log("MockNFT:    ", address(nft));
        console.log("NFTMarket:  ", address(market));
        console.log("========================");
    }
}
