// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract NFTMarket is EIP712 {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address paymentToken; // 新增支付代币字段[4,5](@ref)
        bool isActive;
    }

    struct Mint {
        address to;
        uint256 tokenId;
    }

    bytes32 public constant MINT_TYPEHASH = keccak256("Mint(address to,uint256 tokenId)");

    address public projectSigner;
    mapping(bytes => bool) public usedSignatures;
    mapping(address => mapping(uint256 => Listing)) public listings;
    
    event Listed(address indexed seller, address nftContract, uint256 tokenId, uint256 price, address paymentToken);
    event Purchased(address indexed buyer, address nftContract, uint256 tokenId, address paymentToken);
    event PermitPurchased(address indexed buyer, address nftContract, uint256 tokenId, address paymentToken);

    constructor(address _projectSigner) EIP712("NFTMarket", "1.0.0") {
        projectSigner = _projectSigner;
    }

    // 上架时指定支付代币
    function list(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price,
        address _paymentToken
    ) external {
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);
        listings[_nftContract][_tokenId] = Listing({
            seller: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            paymentToken: _paymentToken,
            isActive: true
        });
        emit Listed(msg.sender, _nftContract, _tokenId, _price, _paymentToken);
    }

    // 使用ERC20代币购买
    function purchase(address _nftContract, uint256 _tokenId) external {
        Listing storage listing = listings[_nftContract][_tokenId];
        require(listing.isActive, "Item not for sale");
        
        IERC20 paymentToken = IERC20(listing.paymentToken);
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "Insufficient token balance");
        
        _executePurchase(listing, msg.sender);
        emit Purchased(msg.sender, _nftContract, _tokenId, listing.paymentToken);
    }

    function hashMint(Mint memory mint) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MINT_TYPEHASH,
                    mint.to,
                    mint.tokenId
                )
            )
        );
    }

    // 白名单代币支付验证
    function permitBuy(
        address _nftContract,
        uint256 _tokenId,
        Mint memory mint,
        bytes memory signature
    ) external {
        require(mint.to == msg.sender, "Invalid mint recipient"); // 确保签名的接收者是购买者
        Listing storage listing = listings[_nftContract][_tokenId];
        require(listing.isActive, "Item not for sale");
        require(!usedSignatures[signature], "Signature already used");

        // 验证签名
        bytes32 digest = hashMint(mint);
        require(digest.recover(signature) == projectSigner, "Invalid signature");

        IERC20 paymentToken = IERC20(listing.paymentToken);
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "Insufficient token balance");

        usedSignatures[signature] = true;
        _executePurchase(listing, msg.sender);
        emit PermitPurchased(msg.sender, _nftContract, _tokenId, listing.paymentToken);
        
    }

    // 白名单代币支付验证
    // function permitBuy(
    //     address _nftContract,
    //     uint256 _tokenId,
    //     bytes memory signature
    // ) external {
    //     Listing storage listing = listings[_nftContract][_tokenId];
    //     require(listing.isActive, "Item not for sale");
    //     require(!usedSignatures[signature], "Signature already used");

    //     // 验证签名包含代币信息
    //     bytes32 messageHash = keccak256(abi.encodePacked(
    //         msg.sender,
    //         _nftContract,
    //         _tokenId,
    //         listing.price,
    //         listing.paymentToken
    //     ));
    //     address signer = messageHash.toEthSignedMessageHash().recover(signature);
    //     require(signer == projectSigner, "Invalid signature");

    //     IERC20 paymentToken = IERC20(listing.paymentToken);
    //     require(paymentToken.balanceOf(msg.sender) >= listing.price, "Insufficient token balance");

    //     usedSignatures[signature] = true;
    //     _executePurchase(listing, msg.sender);
    //     emit PermitPurchased(msg.sender, _nftContract, _tokenId, listing.paymentToken);
    // }

    function _executePurchase(Listing storage listing, address buyer) private {
        listing.isActive = false;
        
        // ERC20代币转账
        IERC20(listing.paymentToken).safeTransferFrom(
            buyer,
            listing.seller,
            listing.price
        );
        
        IERC721(listing.nftContract).transferFrom(address(this), buyer, listing.tokenId);
    }
}