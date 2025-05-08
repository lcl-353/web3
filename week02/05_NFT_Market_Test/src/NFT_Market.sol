// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarket {
    struct Listing {
        address seller;
        address payToken;
        uint256 price;
    }

    // nftAddress => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    event Listed(address indexed nft, uint256 indexed tokenId, address seller, address payToken, uint256 price);
    event Purchased(address indexed nft, uint256 indexed tokenId, address buyer, address seller, address payToken, uint256 price);

    function list(address nft, uint256 tokenId, address payToken, uint256 price) external {
        require(price > 0, "Price must be greater than zero");
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "Not the owner");
        require(
            IERC721(nft).getApproved(tokenId) == address(this) ||
            IERC721(nft).isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );

        listings[nft][tokenId] = Listing({
            seller: msg.sender,
            payToken: payToken,
            price: price
        });

        emit Listed(nft, tokenId, msg.sender, payToken, price);
    }

    function buy(address nft, uint256 tokenId) external {
        Listing memory item = listings[nft][tokenId];
        require(item.seller != address(0), "Item not listed");
        require(msg.sender != item.seller, "Cannot buy your own NFT");

        delete listings[nft][tokenId];

        require(
            IERC20(item.payToken).transferFrom(msg.sender, item.seller, item.price),
            "Payment failed"
        );

        IERC721(nft).safeTransferFrom(item.seller, msg.sender, tokenId);

        emit Purchased(nft, tokenId, msg.sender, item.seller, item.payToken, item.price);
    }
}
