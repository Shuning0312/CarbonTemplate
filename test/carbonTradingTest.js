const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarbonTradingTemplate", function () {
  
  let CarbonTradingTemplate;
  let carbonTradingTemplate;
  let admin, issuer, trader1, trader2, auditor;

  beforeEach(async function () {
    [admin, issuer, trader1, trader2, auditor] = await ethers.getSigners();

    CarbonTradingTemplate = await ethers.getContractFactory("CarbonTradingTemplate");
    carbonTradingTemplate = await CarbonTradingTemplate.deploy(); // 部署合约
    await carbonTradingTemplate.waitForDeployment(); // 确保部署完成

    // 设置角色
    await carbonTradingTemplate.connect(admin).grantRole(await carbonTradingTemplate.ISSUER_ROLE(), issuer.address);
    await carbonTradingTemplate.connect(admin).grantRole(await carbonTradingTemplate.AUDITOR_ROLE(), auditor.address);
  });

  it("管理员应能够添加新账户并授予交易员角色", async function () {
    await carbonTradingTemplate.connect(admin).addAccount(trader1.address, "Trader1 Organization");
    const isTrader = await carbonTradingTemplate.checkRole(trader1.address, 1);
    expect(isTrader).to.be.true;
  });

  it("碳信用发放者应能够向账户发放碳信用额度", async function () {
    await carbonTradingTemplate.connect(admin).addAccount(trader1.address, "Trader1 Organization");
    await carbonTradingTemplate.connect(issuer).issueCarbonCredit(trader1.address, 100);

    const accountData = await carbonTradingTemplate.accounts(trader1.address);
    expect(accountData.totalCredits).to.equal(100);
  });

  it("交易员应能够交易碳信用额度", async function () {
    await carbonTradingTemplate.connect(admin).addAccount(trader1.address, "Trader1 Organization");
    await carbonTradingTemplate.connect(admin).addAccount(trader2.address, "Trader2 Organization");
    await carbonTradingTemplate.connect(issuer).issueCarbonCredit(trader1.address, 200);

    await carbonTradingTemplate.connect(trader1).tradeCarbonCredits(trader2.address, 50);

    const trader1Credits = (await carbonTradingTemplate.accounts(trader1.address)).totalCredits;
    const trader2Credits = (await carbonTradingTemplate.accounts(trader2.address)).totalCredits;

    expect(trader1Credits).to.equal(150);
    expect(trader2Credits).to.equal(50);
  });

  it("审计员应能够审查碳信用额度", async function () {
    await carbonTradingTemplate.connect(admin).addAccount(trader1.address, "Trader1 Organization");
    await carbonTradingTemplate.connect(issuer).issueCarbonCredit(trader1.address, 100);

    const [creditId, amount, issuedBy, isValid] = await carbonTradingTemplate.connect(auditor).auditCarbonCredits(trader1.address, 0);
    expect(amount).to.equal(100);
  });

  it("交易员应能够查看其交易记录", async function () {
    await carbonTradingTemplate.connect(admin).addAccount(trader1.address, "Trader1 Organization");
    await carbonTradingTemplate.connect(admin).addAccount(trader2.address, "Trader2 Organization");
    await carbonTradingTemplate.connect(issuer).issueCarbonCredit(trader1.address, 200);

    await carbonTradingTemplate.connect(trader1).tradeCarbonCredits(trader2.address, 50);

    const [tradeId, seller, buyer, amount, tradeDate] = await carbonTradingTemplate.connect(trader1).getTradeRecord(trader1.address, 0);
    expect(amount).to.equal(50);
    expect(buyer).to.equal(trader2.address);
  });

});