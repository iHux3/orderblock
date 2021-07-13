const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");

describe("OrderBlock contract", function() {
    let owner, orderBlock, tokenBase, tokenQuote, marketId, notFillableId;
    it("deploy contracts and creates market", async function() {
        [owner] = await ethers.getSigners();
        const Utils = await ethers.getContractFactory("Utils");
        const utils = await Utils.deploy();
        const OrderBlock = await ethers.getContractFactory("OrderBlock", { libraries: { Utils: utils.address }});
        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
        orderBlock = await OrderBlock.deploy();
        tokenBase = await ERC20Mock.deploy("MOCK1", "MOCK1", owner.address, web3.utils.toWei("100"));
        tokenQuote = await ERC20Mock.deploy("MOCK2", "MOCK2", owner.address, web3.utils.toWei("100"));
        await orderBlock.createMarket(tokenBase.address, tokenQuote.address);
        marketId = 1;
    });

    it("creating market with swapped base with quote fails", async function() {
        await expect(orderBlock.createMarket(tokenQuote.address, tokenBase.address)).to.be.revertedWith("PAIR_EXISTS");
    });

    it("places buy limit orders", async function() {
        const amount = web3.utils.toWei("1", "ether");
        const amountTotal = web3.utils.toWei("3", "ether");
        const tokenBalanceBefore = await tokenQuote.balanceOf(owner.address);
        await tokenQuote.approve(orderBlock.address, amountTotal);

        await orderBlock.createOrder(marketId, web3.utils.toWei("1"), amount, 0, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("0.75"), amount, 0, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("0.5"), amount, 0, 0, 0);

        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(0);

        const tokenBalanceAfter = await tokenQuote.balanceOf(owner.address);
        expect(tokenBalanceBefore).to.equal(BigNumber.from(tokenBalanceAfter).add(BigNumber.from(amountTotal)));
    });

    it("places sell limit orders", async function() {
        const amount = web3.utils.toWei("1");
        const amountTotal = web3.utils.toWei("3");
        const tokenBalanceBefore = await tokenBase.balanceOf(owner.address);
        await tokenBase.approve(orderBlock.address, amountTotal);

        await orderBlock.createOrder(marketId, web3.utils.toWei("1.5"), amount, 1, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("3"), amount, 1, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("4"), amount, 1, 0, 0);

        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("1.25"));

        const tokenBalanceAfter = await tokenBase.balanceOf(owner.address);
        expect(tokenBalanceBefore).to.equal(BigNumber.from(tokenBalanceAfter).add(BigNumber.from(amountTotal)));
    });

    it("places buy stop orders", async function() {
        const amount = web3.utils.toWei("1.5");
        const amountTotal = web3.utils.toWei("13");
        const tokenBalanceBefore = await tokenQuote.balanceOf(owner.address);
        await tokenQuote.approve(orderBlock.address, amountTotal);

        await orderBlock.createOrder(marketId, web3.utils.toWei("1.6"), amount, 0, 1, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("1.6"), amount, 0, 1, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("2.2"), web3.utils.toWei("10"), 0, 1, 0); // not fillable
        const freeOrderId = await orderBlock.freeOrderId();
        notFillableId = freeOrderId - 1;
        
        const tokenBalanceAfter = await tokenQuote.balanceOf(owner.address);
        expect(tokenBalanceBefore).to.equal(BigNumber.from(tokenBalanceAfter).add(BigNumber.from(amountTotal)));
    });

    it("cancels first buy limit order", async function() {
        await orderBlock.cancelOrder(1);
        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("1.125"));
    });

    it("reverts too big sell market order", async function() {
        const amount = web3.utils.toWei("4");
        await tokenBase.approve(orderBlock.address, amount);
        await expect(orderBlock.createOrder(marketId, 0, amount, 1, 2, 0)).to.be.revertedWith("NOT_FILLABLE");
    });

    it("executes sell market order", async function() {
        const amount = web3.utils.toWei("2");
        const tokenBalanceBefore = await tokenQuote.balanceOf(owner.address);
        await tokenBase.approve(orderBlock.address, amount);

        await orderBlock.createOrder(marketId, 0, amount, 1, 2, 0);

        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("1"));
        const tokenBalanceAfter = await tokenQuote.balanceOf(owner.address);
        const expectedTokenAmount = web3.utils.toWei("1.333333333333333333");
        expect(tokenBalanceBefore).to.equal(BigNumber.from(tokenBalanceAfter).sub(BigNumber.from(expectedTokenAmount)));
    });

    it("places 50 sell limit orders and executes buy market order that executes these limit orders", async function() {
        const amount = web3.utils.toWei("1");
        const amountTotal = web3.utils.toWei("50");
        await tokenBase.approve(orderBlock.address, amountTotal);

        for (let i = 0; i < 50; i++) {
            await orderBlock.createOrder(marketId, web3.utils.toWei("1.1"), amount, 1, 0, 0);
        }

        const amountBuy = web3.utils.toWei("55");
        await tokenQuote.approve(orderBlock.address, amountBuy);
        await orderBlock.createOrder(marketId, 0, amountBuy, 0, 2, 0);

        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("1"));
    });

    it("executes buy market order and triggers 2 buy stop orders", async function () {
        const amount = web3.utils.toWei("1.5");
        await tokenQuote.approve(orderBlock.address, amount);

        await orderBlock.createOrder(marketId, 0, amount, 0, 2, 0);

        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("2.25"));

        // one stop order failed
        const orderInfo = await orderBlock.orders(notFillableId);
        expect(orderInfo.typee).to.equal(5);
    });
});