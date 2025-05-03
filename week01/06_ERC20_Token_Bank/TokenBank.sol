// 一：编写一个符合ERC20标准的token满足以下条件
// 设置 Token 名称（name）："BaseERC20"
// 设置 Token 符号（symbol）："BERC20"
// 设置 Token 小数位decimals：18
// 设置 Token 总量（totalSupply）:100,000,000
// 允许任何人查看任何地址的 Token 余额（balanceOf）
// 允许 Token 的所有者将他们的 Token 发送给任何人（transfer）；转帐超出余额时抛出异常(require),并显示错误消息 “ERC20: transfer amount exceeds balance”。
// 允许 Token 的所有者批准某个地址消费他们的一部分Token（approve）
// 允许任何人查看一个地址可以从其它账户中转账的代币数量（allowance）
// 允许被授权的地址消费他们被授权的 Token 数量（transferFrom）；
// 转帐超出余额时抛出异常(require)，异常信息：“ERC20: transfer amount exceeds balance”
// 转帐超出授权数量时抛出异常(require)，异常消息：“ERC20: transfer amount exceeds allowance”。



// 二：编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

// TokenBank 有两个方法：

// deposit() : 需要记录每个地址的存入数量；
// withdraw（）: 用户可以提取自己的之前存入的 token。
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


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
        // write your code here
        //require(_value <= balances[msg.sender], "ERC20: approve amount exceeds balance");  
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {   
        // write your code here     
        return allowances[_owner][_spender];
    }
}

/// @dev 只需要 ERC20 中的这几个接口
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

/// @title TokenBank
/// @notice 允许用户存取 BaseERC20 代币
contract TokenBank {
    /// @dev 存款记录：用户地址 => 存入数量
    mapping(address => uint256) public deposits;

    /// @dev 被存入的 ERC20 代币合约
    IERC20 public immutable token;

    /// @param _tokenAddress 已部署的 BaseERC20 合约地址
    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    /// @notice 将指定数量的代币存入本合约
    /// @param amount 要存入的代币数量
    function deposit(uint256 amount) external {
        require(amount > 0, "TokenBank: zero amount");

        // 从调用者账户扣除代币，需先在 token 合约上 approve 本合约
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        require(ok, "TokenBank: transferFrom failed");

        // 记录存款
        deposits[msg.sender] += amount;
    }

    /// @notice 提取先前存入的代币
    /// @param amount 要提取的代币数量
    function withdraw(uint256 amount) external {
        uint256 bal = deposits[msg.sender];
        require(amount > 0 && amount <= bal, "TokenBank: insufficient balance");

        // 更新存款记录
        deposits[msg.sender] = bal - amount;

        // 将代币返还给用户
        bool ok = token.transfer(msg.sender, amount);
        require(ok, "TokenBank: transfer failed");
    }
}

