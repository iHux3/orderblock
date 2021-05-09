async function main() {
    const Utils = await ethers.getContractFactory("Utils");
    const utils = await Utils.deploy();
    const OrderBlock = await ethers.getContractFactory("OrderBlock", { libraries: { Utils: utils.address }});
    const orderBlock = await OrderBlock.deploy();
    const TestToken1 = await ethers.getContractFactory("TestToken1");
    const testToken1 = await TestToken1.deploy();

    await orderBlock.createMarket("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", testToken1.address);
    
    const value = web3.utils.toWei('1', 'ether');
    await testToken1.approve(orderBlock.address, web3.utils.toWei('10', 'ether'));
    await orderBlock.createOrder(1, web3.utils.toWei('0.5', 'ether'), value, 0, 0, 0);
    await orderBlock.createOrder(1, web3.utils.toWei('1', 'ether'), value, 0, 0, 0);
    await orderBlock.createOrder(1, web3.utils.toWei('1', 'ether'), value, 0, 0, 0);
    await orderBlock.createOrder(1, web3.utils.toWei('1.5', 'ether'), value, 1, 0, 0, {value: value});
    await orderBlock.createOrder(1, web3.utils.toWei('2', 'ether'), value, 1, 0, 0, {value: value});

    await orderBlock.createOrder(1, web3.utils.toWei('0.25', 'ether'), value, 1, 1, 0, {value: web3.utils.toWei('1.005', 'ether')});
    await orderBlock.createOrder(1, web3.utils.toWei('1', 'ether'), value, 1, 1, 0, {value: web3.utils.toWei('1.005', 'ether')});
    await orderBlock.createOrder(1, web3.utils.toWei('1.5', 'ether'), value, 0, 1, 0, {value: web3.utils.toWei('0.005', 'ether')});
    await orderBlock.createOrder(1, web3.utils.toWei('2.5', 'ether'), value, 0, 1, 0, {value: web3.utils.toWei('0.005', 'ether')});
  
    console.log("OrderBlock deployed to:", orderBlock.address);
    console.log("Token deployed to:", testToken1.address);
}
  
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
});