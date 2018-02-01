var Fundraiser = artifacts.require("Fundraiser");

contract('Fundraiser', function(accounts) {
    let fundr;

    beforeEach(async function () {
        fundr = await Fundraiser.new(accounts[0], accounts[1]);
    });

    it("is initialized not to accept funds", async function() {
        const accept = await fundr.accept.call();
        assert.equal(accept, false);
    });

    it("reverts if someone tries to contribute before it's open", async function() {
        try {
            await fundr.Contribute(1234);
            assert.fail(null, null, "Contract should have raised.");
        } catch(error) {
            assert(error.message == "VM Exception while processing transaction: revert");
        }
    });

    it("reverts when ether is sent to it with no data", async function() {
        try {
            await fundr.sendTransaction({from: accounts[3], value: 1});
            assert.fail(null, null, "Contract should have raised.");
        } catch(error) {
            assert(error.message == "VM Exception while processing transaction: revert");
        }
    });
});
