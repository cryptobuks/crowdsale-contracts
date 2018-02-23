var Fundraiser = artifacts.require("Fundraiser");

module.exports = function(deployer) {
    account1 = 1;
    account2 = 2;
    account3 = 3;
    account4 = 4;
    account5 = 5;
    deployer.deploy(Fundraiser, account1, account2, account3, account4, account5);
};
