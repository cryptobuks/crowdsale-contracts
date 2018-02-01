var Fundraiser = artifacts.require("Fundraiser");

module.exports = function(deployer) {
	account1 = account;
	account2 = account;
    deployer.deploy(Fundraiser, account1, account2);
};
