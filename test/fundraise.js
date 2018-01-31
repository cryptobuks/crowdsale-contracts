var Fundraiser = artifacts.require("Fundraiser");

contract('Fundraise', function(accounts) {
    let fundr;

    beforeEach(async function () {
        fundr = await Fundraiser.new(1234, 4321);
    });

    it("is initialized not to accept funds", async function() {
        const accept = await fundr.accept();
        assert.equal(accept, false);
    });


    it("reverts if someone tries to contribute before it's open", async function() {
        try {
            await fundr.Contribute(1234);
            assert.fail(null, null, "Contract should have raised.")
        } catch(error) {
            assert(error.message == "VM Exception while processing transaction: revert");
        }
    });
});
