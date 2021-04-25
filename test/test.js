describe("OrderBlock contract", function() {
  it("complex situation", async function() {
    const [owner] = await ethers.getSigners();
    const OrderBlock = await ethers.getContractFactory("OrderBlock");
    const TestToken1 = await ethers.getContractFactory("TestToken1");
    const orderBlock = await OrderBlock.deploy();
    const testToken1 = await TestToken1.deploy();
    await orderBlock.createMarket("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", testToken1.address);
    
    await testToken1.approve(orderBlock.address, web3.utils.toWei('10', 'ether'));
    await orderBlock.createOrder(1, web3.utils.toWei('1', 'ether'), web3.utils.toWei('1', 'ether'), 0, 0, 0);
    await orderBlock.createOrder(1, web3.utils.toWei('2', 'ether'), web3.utils.toWei('1', 'ether'), 1, 0, 0, {value: web3.utils.toWei('1', 'ether')});
    await orderBlock.createOrder(1, web3.utils.toWei('3', 'ether'), web3.utils.toWei('1', 'ether'), 1, 0, 0, {value: web3.utils.toWei('1', 'ether')});
    await orderBlock.createOrder(1, web3.utils.toWei('1.8', 'ether'), web3.utils.toWei('3', 'ether'), 0, 1, 0);
   
    await orderBlock.createOrder(1, web3.utils.toWei('1', 'ether'), web3.utils.toWei('2', 'ether'), 0, 2, 0);
    
    /*let price = await orderBlock.getPrice(1);
    console.log(price.toString());*/

    /*let balance = await web3.eth.getBalance(owner.address);
    console.log(web3.utils.fromWei(balance));*/
  });

  it("buy limit, sell market", async function() {
    /*const [owner] = await ethers.getSigners();
    const OrderBlock = await ethers.getContractFactory("OrderBlock");
    const TestToken1 = await ethers.getContractFactory("TestToken1");
    const orderBlock = await OrderBlock.deploy();
    const testToken1 = await TestToken1.deploy();
    await orderBlock.createMarket("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", testToken1.address);
    
    const value = web3.utils.toWei('1', 'ether');
    await testToken1.approve(orderBlock.address, web3.utils.toWei('2', 'ether'));
    await orderBlock.createOrder(1, value, value, 0, 0, 0);
    await orderBlock.createOrder(1, value, value, 0, 0, 0);
   
    await orderBlock.createOrder(1, value, web3.utils.toWei('2', 'ether'), 1, 2, 0, {value: web3.utils.toWei('2', 'ether')});

    let balance = await testToken1.balanceOf(owner.address);
    console.log(web3.utils.fromWei(balance.toString()));*/
  });
});