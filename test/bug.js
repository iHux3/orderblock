const { BigNumber } = require("@ethersproject/bignumber");
const { expect } = require("chai");

describe("OrderBlock contract", function() {
    let owner, orderBlock, tokenBase, tokenQuote, marketId, notFillableId;
    it("bug case", async function() {
        [owner] = await ethers.getSigners();
        const Utils = await ethers.getContractFactory("Utils");
        const utils = await Utils.deploy();
        const OrderBlock = await ethers.getContractFactory("OrderBlock", { libraries: { Utils: utils.address }});
        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
        orderBlock = await OrderBlock.deploy();
        tokenBase = await ERC20Mock.deploy("MOCK1", "MOCK1", owner.address, web3.utils.toWei("10000"));
        tokenQuote = await ERC20Mock.deploy("MOCK2", "MOCK2", owner.address, web3.utils.toWei("10000"));
        await orderBlock.createMarket(tokenBase.address, tokenQuote.address);
        marketId = 1;
        
        await tokenBase.approve(orderBlock.address, web3.utils.toWei("10000"));
        await tokenQuote.approve(orderBlock.address, web3.utils.toWei("10000"));

        const hundred = web3.utils.toWei("100");
        await orderBlock.createOrder(marketId, web3.utils.toWei("5"), hundred, 1, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("7"), hundred, 1, 0, 0);

        await orderBlock.createOrder(marketId, web3.utils.toWei("4"), hundred, 0, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("2"), hundred, 0, 0, 0);
        await orderBlock.createOrder(marketId, web3.utils.toWei("4.1"), hundred, 0, 0, 0);

        let actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("4.55"));

        await orderBlock.createOrder(marketId, 0, web3.utils.toWei("30"), 1, 2, web3.utils.toWei("1"));

        actualPrice = await orderBlock.getPrice(marketId);
        expect(actualPrice).to.equal(web3.utils.toWei("4.5"));

        const orderData3 = await orderBlock.orders(3);
        expect(orderData3.typee).to.equal(0);
        const orderData5 = await orderBlock.orders(5);
        expect(orderData5.typee).to.equal(3);
    });
});