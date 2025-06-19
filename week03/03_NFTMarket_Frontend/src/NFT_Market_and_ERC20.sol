// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


interface IERC20Receiver {
    function tokensReceived(address from, uint256 amount, uint256 data) external;
}

contract BaseERC20 {
    string public name; 
    string public symbol; 
    uint8 public decimals; 

    uint256 public totalSupply; 

    mapping (address => uint256) balances; 

    mapping (address => mapping (address => uint256)) allowances; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() public {
        // write your code here
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 100000000000000000000000000;
        // set name,symbol,decimals,totalSupply

        balances[msg.sender] = totalSupply;  
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(_value <= balances[msg.sender], "ERC20: transfer amount exceeds balance");
        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);  
        return true;   
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(_value <= balances[_from], "ERC20: transfer amount exceeds balance");
        require(_value <= allowances[_from][msg.sender], "ERC20: transfer amount exceeds allowance");
        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        
        emit Transfer(_from, _to, _value); 
        return true; 
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {  
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {      
        return allowances[_owner][_spender];
    }

    // safer transfer approach
    function transferWithCallback(address _to, uint256 _value, uint256 data) public returns (bool) {
        require(_value <= balances[msg.sender], "ERC20: transfer amount exceeds balance");

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);

        // if caller is Contract, then try tokensReceived
        if (isContract(_to)) {
            try NFTMarket(_to).tokensReceived(msg.sender, _value, data) {
                // success callback
            } catch Error(string memory reason) {
                // 直接抛出接收合约的 revert 原因
                revert(reason);
            } catch {
                revert("ERC20: tokensReceived callback failed");
            }
        }

        return true;
    }

    function isContract(address _addr) internal view returns (bool) {
        return _addr.code.length > 0;
    }
}

/// @dev 只需要 ERC20 中的这几个接口
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}


/// @title NFTMarket
/// @notice 使用 BaseERC20.transferWithCallback 调用此合约的 tokensReceived 完成 NFT 购买
contract NFTMarket is IERC20Receiver {
    IERC20 public immutable paymentToken;
    IERC721 public immutable nftContract;

    struct Listing {
        address seller;
        uint256 price;
    }

    /// @dev tokenId => Listing
    mapping(uint256 => Listing) public listings;

    /// @notice Emitted when an NFT is listed for sale
    /// @param tokenId The ID of the NFT
    /// @param seller The address of the seller
    /// @param price The price of the NFT in payment tokens
    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    
    /// @notice Emitted when an NFT is purchased
    /// @param tokenId The ID of the NFT that was bought
    /// @param buyer The address of the buyer
    /// @param price The price paid for the NFT in payment tokens
    event Bought(uint256 indexed tokenId, address indexed buyer, uint256 price);
    
    /// @notice Emitted for debugging token receipt
    /// @param tokenId The token ID being processed
    /// @param buyer The address of the buyer
    /// @param price The price paid
    event Print(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor(address _paymentToken, address _nftContract) {
        paymentToken = IERC20(_paymentToken);
        nftContract  = IERC721(_nftContract);
    }

    /// @notice NFT 持有者上架自己的 NFT，同时将 NFT 转入本合约托管
    /// @param tokenId 要上架的 NFT ID
    /// @param price   购买价格（单位是 paymentToken 的最小单位）
    function list(uint256 tokenId, uint256 price) external {
        require(nftContract.ownerOf(tokenId) == msg.sender, "Only owner can list");
        require(price > 0, "Price must be > 0");

        // 托管 NFT 到市场合约
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({
            seller: msg.sender,
            price:  price
        });

        // Emit event when NFT is listed - for backend monitoring
        emit Listed(tokenId, msg.sender, price);
    }

    /// @notice BaseERC20.transferWithCallback 在转账时会调用此方法
    /// @param from  调用 transferWithCallback 的原始调用者
    /// @param amount 转账的 paymentToken 数量
    /// @param data  买家传入的额外数据，这里用它来传递 tokenId
    function tokensReceived(
        address from,
        uint256 amount,
        uint256 data
    ) external override {
        // Debug event to track token receipt - for backend monitoring
        emit Print(data, from, amount);
        
        // 仅允许绑定的 ERC20 合约调用
        require(msg.sender == address(paymentToken), "Invalid token sender");

        uint256 tokenId = data;

        Listing memory item = listings[tokenId];
        require(item.price > 0,          "NFT not listed");
        require(amount == item.price,    "Incorrect payment amount");

        require(
            paymentToken.transfer(item.seller, item.price),
            "Payment failed"
        );

        // 支付已经由 transferWithCallback 完成，这里直接把 NFT 发给买家 买家要有Approve
        nftContract.transferFrom(address(this), from, tokenId);

        // Emit purchase event - for backend monitoring
        emit Bought(tokenId, from, amount);

        // 清理上架信息
        delete listings[tokenId];
    }

    /// @notice 如果需要手动购买，也可以保留原 buyNFT 接口
    function buyNFT(uint256 tokenId) external {
        Listing memory item = listings[tokenId];
        require(item.price > 0, "Not listed");

        // 传统流程：先 approve，再 transferFrom
        require(
            paymentToken.transferFrom(msg.sender, item.seller, item.price),
            "Payment failed"
        );
        nftContract.transferFrom(address(this), msg.sender, tokenId);

        // Emit purchase event - for backend monitoring
        emit Bought(tokenId, msg.sender, item.price);
        delete listings[tokenId];
    }
}

