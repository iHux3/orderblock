const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");

describe("OrderBlock contract", function() {
    let owner, orderBlock, testToken1, marketId;
    it("deploy contracts and creates market ETH-TEST", async function() {
        [owner] = await ethers.getSigners();
        const Utils = await ethers.getContractFactory("Utils");
        const utils = await Utils.deploy();
        const OrderBlock = await ethers.getContractFactory("OrderBlock", { libraries: { Utils: utils.address }});
        const TestToken1 = await ethers.getContractFactory("TestToken1");
        orderBlock = await OrderBlock.deploy();
        testToken1 = await TestToken1.deploy();
        await orderBlock.createMarket("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", testToken1.address);
        marketId = 1;
    });

    it("places buy limit orders", async function() {
        const amount = web3.utils.toWei("1", "ether");
        const amountTotal = web3.utils.toWei("3", "ether");
        const tokenBalanceBefore = await testToken1.balanceOf(owner.address);
        await testToken1.approve(orderBlock.address, amountTotal);

        await orderBlock.createOrder(marketId, web3.utils.toWei("1"), amount, 0, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("0.75"), amount, 0, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("0.5"), amount, 0, 0, 0);

        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(0);

        const tokenBalanceAfter = await testToken1.balanceOf(owner.address);
        expect(tokenBalanceBefore).to.equal(BigNumber.from(tokenBalanceAfter).add(BigNumber.from(amountTotal)));
    });

    it("places sell limit orders", async function() {
        const amount = web3.utils.toWei("1");
        const amountTotal = web3.utils.toWei("3");
        const ethBalanceBefore = await web3.eth.getBalance(owner.address);

        await orderBlock.createOrder(marketId, web3.utils.toWei("1.5"), amount, 1, 0, 0, {value: amount});
        await orderBlock.createOrder(marketId, web3.utils.toWei("1.5"), amount, 1, 0, 0, {value: amount});
        await orderBlock.createOrder(marketId, web3.utils.toWei("2"), amount, 1, 0, 0, {value: amount});

        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("1.25"));

        const ethBalanceAfter = await web3.eth.getBalance(owner.address);
        expect(ethBalanceAfter).to.below(BigNumber.from(ethBalanceBefore).sub(BigNumber.from(amountTotal)));
    });

    
    it("cancels first buy limit order", async function() {
        await orderBlock.cancelOrder(1);
        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("1.125"));
    });

    it("reverts too big sell market order", async function() {
        const amount = web3.utils.toWei("4");
        await expect(orderBlock.createOrder(marketId, web3.utils.toWei("1.125"), amount, 1, 2, 0, {value: amount})).to.be.revertedWith("NOT_ENOUGH_ORDERS");
    });

    it("executes sell market order", async function() {
        const amount = web3.utils.toWei("2");
        const tokenBalanceBefore = await testToken1.balanceOf(owner.address);

        await orderBlock.createOrder(marketId, web3.utils.toWei("1.125"), amount, 1, 2, 0, {value: amount});
        const actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("1"));

        const tokenBalanceAfter = await testToken1.balanceOf(owner.address);
        const expectedTokenAmount = web3.utils.toWei("1.333333333333333333");
        expect(tokenBalanceBefore).to.equal(BigNumber.from(tokenBalanceAfter).sub(BigNumber.from(expectedTokenAmount)));
    });
});