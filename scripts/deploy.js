async function main() {
    const Utils = await ethers.getContractFactory("Utils");
    const utils = await Utils.deploy();
    const OrderBlock = await ethers.getContractFactory("OrderBlock", { libraries: { Utils: utils.address }});
    const orderBlock = await OrderBlock.deploy();
  
    console.log("OrderBlock deployed to:", orderBlock.address);
}
  
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
});