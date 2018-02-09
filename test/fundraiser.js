var Fundraiser = artifacts.require("Fundraiser");

contract('Fundraiser', function(accounts) {
    let fundr;
    let signer1_address;
    let signer2_address;
    let contributer_address;
    let destination_address;

    beforeEach(async function () {
        signer1_address = accounts[1];
        signer2_address = accounts[2];
        contributer_address = accounts[3];
        destination_address = accounts[4];

        fundr = await Fundraiser.new(signer1_address, signer2_address);
    });

    it("reverts when ether is sent to it with no data", async function() {
        try {
            await fundr.sendTransaction({from: contributer_address, value: 1});
            assert.fail(null, null, "Contract should have raised.");
        } catch(error) {
            assert.equal(error.message, "VM Exception while processing transaction: revert");
        }
    });

    describe("when trying to contribute", function() {
        it("allow if it's a signer", async function() {
            const balance_before = await web3.eth.getBalance(fundr.address);
            const amount_sent = 1

            await fundr.contribute(
                // This hex is the concatenation of a fake public key and its double hash.
                web3.toHex("0x0000000000000000000000000000000000000000f6eab7b9"),
                {from: signer1_address, value: amount_sent}
            );

            const balance_after = await web3.eth.getBalance(fundr.address)
            assert(balance_after.equals(balance_before.plus(amount_sent)));
        });

        it("allow if it's not a signer", async function() {
            const balance_before = await web3.eth.getBalance(fundr.address);
            const amount_sent = 1;

            await fundr.contribute(
                // This hex is the concatenation of a fake public key and its double hash.
                web3.toHex("0x0000000000000000000000000000000000000000f6eab7b9"),
                {from: contributer_address, value: amount_sent}
            );

            const balance_after = await web3.eth.getBalance(fundr.address);
            assert(balance_after.equals(balance_before.plus(amount_sent)));
        });

        it("revert if pk checksum is wrong", async function() {
            try {
                await fundr.contribute(
                    // This hex of all zeros is wrong because it needs its own double hash concatenated on the end.
                    web3.toHex("0x000000000000000000000000000000000000000000000000"),
                    {from: contributer_address}
                );
                assert.fail(null, null, "Contract should have raised.");
            } catch(error) {
                assert.equal(error.message, "VM Exception while processing transaction: revert");
            }
        });
    });

    describe("when trying to withdraw", function() {
        beforeEach(async function () {
            await fundr.contribute(
                // This hex is the concatenation of a fake public key and its double hash.
                web3.toHex("0x0000000000000000000000000000000000000000f6eab7b9"),
                {from: contributer_address, value: 1}
            );
        });

        it("allows one signer to propose but not withdraw", async function() {
            const balance_before = await web3.eth.getBalance(fundr.address);
            await fundr.withdraw(destination_address, 1, {from: signer1_address})
            const balance_after = await web3.eth.getBalance(fundr.address)

            assert(balance_after.equals(balance_before));
        });

        it("allows both signers to withdraw", async function() {
            const amount_withdrawn = 1;

            const balance_before = await web3.eth.getBalance(fundr.address);
            const dest_balance_before = await web3.eth.getBalance(destination_address);

            await fundr.withdraw(destination_address, amount_withdrawn, {from: signer1_address});
            await fundr.withdraw(destination_address, amount_withdrawn, {from: signer2_address});

            const balance_after = await web3.eth.getBalance(fundr.address);
            const dest_balance_after = await web3.eth.getBalance(destination_address);

            // Then make sure that amount was withdrawn
            // plus and equals methods are because these are BigNumbers
            assert(balance_after.plus(amount_withdrawn).equals(balance_before));
            assert(dest_balance_before.plus(amount_withdrawn).equals(dest_balance_after));
        });

        it("allows both signers to withdraw in the other order", async function() {
            const amount_withdrawn = 1;

            const balance_before = await web3.eth.getBalance(fundr.address);
            const dest_balance_before = await web3.eth.getBalance(destination_address);

            await fundr.withdraw(destination_address, amount_withdrawn, {from: signer2_address});
            await fundr.withdraw(destination_address, amount_withdrawn, {from: signer1_address});

            const balance_after = await web3.eth.getBalance(fundr.address);
            const dest_balance_after = await web3.eth.getBalance(destination_address);

            // Then make sure that amount was withdrawn
            // plus and equals methods are because these are BigNumbers
            assert(balance_after.plus(amount_withdrawn).equals(balance_before));
            assert(dest_balance_before.plus(amount_withdrawn).equals(dest_balance_after));
        });

        it("does not allow a non-signer to propose withdrawal", async function() {
            try {
                await fundr.withdraw(destination_address, 1, {from: contributer_address})
                assert.fail(null, null, "Contract should have raised.");
            } catch(error) {
                assert.equal(error.message, "VM Exception while processing transaction: revert");
            }
        });

        it("does not allow the signers to withdraw more than is in the account", async function() {
            const contract_balance_before = await web3.eth.getBalance(fundr.address)
            // plus and equals methods are because these are BigNumbers
            const withdraw_amount = contract_balance_before.plus(1)
            try {
                await fundr.withdraw(destination_address, withdraw_amount, {from: signer1_address})
                assert.fail(null, null, "Contract should have raised.");
            } catch(error) {
                assert.equal(error.message, "VM Exception while processing transaction: revert");
            }
        });
    });
});
