// new task

// 扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。

// 继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。

// （备注：TokenBankV2 需要实现 tokensReceived 来实现存款记录工作）


// old task

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


interface IERC20Receiver {
    function tokensReceived(address from, uint256 amount) external;
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
    function transferWithCallback(address _to, uint256 _value) public returns (bool) {
        require(_value <= balances[msg.sender], "ERC20: transfer amount exceeds balance");

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);

        // if caller is Contract, then try tokensReceived
        if (isContract(_to)) {
            try IERC20Receiver(_to).tokensReceived(msg.sender, _value) {
                // success callback
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

/// @title 扩展：支持 transferWithCallback 的 TokenBankV2
/// @notice 通过回调自动记录用户通过 transferWithCallback 存入的代币
contract TokenBankV2 is TokenBank, IERC20Receiver {
    /// @param _tokenAddress 已部署的 BaseERC20 合约地址
    constructor(address _tokenAddress) TokenBank(_tokenAddress) {}

    /// @notice 回调入口：只有 BaseERC20.transferWithCallback 会调用此方法
    /// @param from 转账发起者
    /// @param amount 转账数量
    function tokensReceived(address from, uint256 amount) external override {
        // 仅允许绑定的 token 合约调用
        require(msg.sender == address(token), "TokenBankV2: invalid token sender");
        // 自动累加存款
        deposits[from] += amount;
    }
}
