async function main() {
    [owner] = await ethers.getSigners();
    const Utils = await ethers.getContractFactory("Utils");
    const utils = await Utils.deploy();
    const OrderBlock = await ethers.getContractFactory("OrderBlock", { libraries: { Utils: utils.address }});
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    orderBlock = await OrderBlock.deploy();
    tokenBase = await ERC20Mock.deploy("MOCK1", "MOCK1", owner.address, web3.utils.toWei("100"));
    tokenQuote = await ERC20Mock.deploy("MOCK2", "MOCK2", owner.address, web3.utils.toWei("100"));
    await orderBlock.createMarket(tokenBase.address, tokenQuote.address);
    
    /*const value = web3.utils.toWei('0.1', 'ether');
    await testToken1.approve(orderBlock.address, web3.utils.toWei('10', 'ether'));
    await orderBlock.createOrder(1, web3.utils.toWei('0.5', 'ether'), value, 0, 0, 0);
    await orderBlock.createOrder(1, web3.utils.toWei('1', 'ether'), value, 0, 0, 0);
    await orderBlock.createOrder(1, web3.utils.toWei('1', 'ether'), value, 0, 0, 0);
    await orderBlock.createOrder(1, web3.utils.toWei('1.5', 'ether'), value, 1, 0, 0, {value: value});
    await orderBlock.createOrder(1, web3.utils.toWei('2', 'ether'), value, 1, 0, 0, {value: value});

    await orderBlock.createOrder(1, web3.utils.toWei('0.25', 'ether'), value, 1, 1, 0, {value: web3.utils.toWei('0.105', 'ether')});
    await orderBlock.createOrder(1, web3.utils.toWei('1', 'ether'), value, 1, 1, 0, {value: web3.utils.toWei('0.105', 'ether')});
    await orderBlock.createOrder(1, web3.utils.toWei('1.5', 'ether'), value, 0, 1, 0, {value: web3.utils.toWei('0.005', 'ether')});
    await orderBlock.createOrder(1, web3.utils.toWei('2.5', 'ether'), value, 0, 1, 0, {value: web3.utils.toWei('0.005', 'ether')});*/

    console.log("done");
}
  
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
});