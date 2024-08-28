// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "hardhat/console.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

// 本合约模板用于碳交易场景，基于OpenZeppelin的AccessControlDefaultAdminRules标准合约模板进行开发。
// 该合约主要用于碳信用额度的分配、交易和核查，旨在简化流程并确保交易的透明性和可信性。
contract CarbonTradingTemplate is AccessControlDefaultAdminRules {

    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");  // 管理员角色，用于管理其他角色的添加或删除
    bytes32 public constant TRADER_ROLE = keccak256("TRADER");  // 交易员角色，用于执行与碳相关操作：买卖碳信用
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR");  // 审计员角色，用于审计和监督碳交易的合规
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER");  // 碳信用发放者角色，用于发放和管理碳信用分配
    uint256 public nextRoleId;
    
    // 描述碳信用额度详细信息
    struct CarbonCredit {
        uint256 creditId;
        uint256 amount;  // 碳信用的数量
        uint256 issuedDate;  // 发行日期
        address issuedBy;  // 发行者地址
        bool isValid;  // 是否有效
    }

    // 碳交易记录
    struct CarbonTrade {
        uint256 tradeId;
        address seller;
        address buyer;
        uint256 amount;
        uint256 tradeDate;
        bool isValid;  // 是否有效
    }

    // 碳信用持有者
    struct AccountData {
        string organizationName;
        uint256 totalCredits;  // 总共持有的碳信用额度
        mapping(uint256 => CarbonCredit) credits;  // 碳信用记录
        uint256 tradeCount;
        mapping(uint256 => CarbonTrade) trades;  // 交易记录
        bool isValid;
    }

    mapping(uint256 => bytes32) roles;
    mapping(address => AccountData) public accounts;

    // 传入当前调用者地址msg.sender，作为初始的默认管理员
    constructor() AccessControlDefaultAdminRules(3 days, msg.sender) {
        roles[0] = ADMIN_ROLE;
        roles[1] = TRADER_ROLE;
        roles[2] = AUDITOR_ROLE;
        roles[3] = ISSUER_ROLE;
        nextRoleId = 4;
    }

    // 检查角色权限的函数
    // 只有拥有DEFAULT_ADMIN_ROLE角色的账户才可以调用这个函数，通常为合约部署者（msg.sender管理员）
    function checkRole(address _checkAddr, uint256 _role) public view onlyRole(DEFAULT_ADMIN_ROLE) returns(bool) {
        return hasRole(roles[_role], _checkAddr);
    }

    // 碳信用发放者相关函数

    // 新增碳信用额度
    // 拥有碳信用发放者角色的账户向_accountAddr发放碳信用
    function issueCarbonCredit(address _accountAddr, uint256 _amount) 
    public onlyRole(ISSUER_ROLE) {
        // 判断账户待发放是否存在
        require(accounts[_accountAddr].isValid, "Error: This account hasn't been added yet.");
        // 获取该账户当前的碳信用总量nextCreditId，作为新的碳信用的标识符
        uint256 nextCreditId = accounts[_accountAddr].totalCredits;
        // 创建一条新的碳信用记录
        // 发放前的碳信用用nextCreditId标识
        // _amount为发放数量
        CarbonCredit memory credit = CarbonCredit(nextCreditId, _amount, block.timestamp, msg.sender, true);
        accounts[_accountAddr].credits[nextCreditId] = credit;  // 更新_accountAddr地址中AccountData的credits（碳信用持有者的碳信用记录），nextCreditId为Carboncredit的标识符
        accounts[_accountAddr].totalCredits += _amount; // 更新碳信用总量
    }

    // 交易员相关函数

    // 新增账户
    function addAccount(address _accountAddr, string memory _organizationName) 
    public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(accounts[_accountAddr].isValid == false, "Error: This address has already been added as an account.");
        // accounts[_accountAddr] = AccountData(_organizationName, 0, 0, true);
        // 逐个字段赋值
        AccountData storage account = accounts[_accountAddr];
        account.organizationName = _organizationName;
        account.totalCredits = 0;
        account.tradeCount = 0;
        account.isValid = true;
        grantRole(TRADER_ROLE, _accountAddr); // 向该地址授予交易员角色
    }

    // 碳信用额度交易
    function tradeCarbonCredits(address _buyerAddr, uint256 _amount) 
    public onlyRole(TRADER_ROLE) {
        // 交易前提：拥有信用数量大于交易数量，余额不足交易中止并抛出错误信息
        require(accounts[msg.sender].totalCredits >= _amount, "Error: Insufficient credits for this transaction.");
        // 计算新的交易ID，这个ID对于卖方和买方都是相同的，用于标识这笔交易
        uint256 nextTradeId = accounts[msg.sender].tradeCount;
        accounts[msg.sender].totalCredits -= _amount; // 卖方减少
        accounts[_buyerAddr].totalCredits += _amount; // 买方增加
        CarbonTrade memory trade = CarbonTrade(nextTradeId, msg.sender, _buyerAddr, _amount, block.timestamp, true);
        // 更新交易双方交易记录
        accounts[msg.sender].trades[nextTradeId] = trade;
        accounts[_buyerAddr].trades[nextTradeId] = trade;
        // 更新交易计数
        accounts[msg.sender].tradeCount++;
        accounts[_buyerAddr].tradeCount++;
    }

    // 查看交易记录
    function getTradeRecord(address _accountAddr, uint256 _tradeId) 
    public view onlyRole(TRADER_ROLE) returns(uint256, address, address, uint256, uint256) {
        require(accounts[_accountAddr].trades[_tradeId].isValid, "Error: Trade record not found.");
        CarbonTrade memory trade = accounts[_accountAddr].trades[_tradeId];
        return (trade.tradeId, trade.seller, trade.buyer, trade.amount, trade.tradeDate);
    }

    // 审计员相关函数

    // 审查碳信用额度
    function auditCarbonCredits(address _accountAddr, uint256 _creditId) 
    public view onlyRole(AUDITOR_ROLE) returns(uint256, uint256, address, bool) {
        require(accounts[_accountAddr].credits[_creditId].isValid, "Error: Credit record not found.");
        CarbonCredit memory credit = accounts[_accountAddr].credits[_creditId];
        return (credit.creditId, credit.amount, credit.issuedBy, credit.isValid);
    }
}