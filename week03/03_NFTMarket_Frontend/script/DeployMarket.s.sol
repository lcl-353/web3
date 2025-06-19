// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/ERC721.sol";
import "../src/NFT_Market_and_ERC20.sol";

contract DeployMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MyNFT with deployer as owner
        MyNFT nft = new MyNFT(deployer);
        console.log("MyNFT deployed at:", address(nft));

        // 2. Deploy BaseERC20 (deployer will be owner as msg.sender)
        BaseERC20 token = new BaseERC20();
        console.log("BaseERC20 deployed at:", address(token));

        // 3. Deploy NFTMarket
        NFTMarket market = new NFTMarket(address(token), address(nft));
        console.log("NFTMarket deployed at:", address(market));

        vm.stopBroadcast();
    }
}
