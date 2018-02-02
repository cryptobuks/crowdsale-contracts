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

    it("is initialized closed", async function() {
        const accept = await fundr.accept.call();
        assert(!accept);
    });

    describe('when closed', function() {
        describe("when trying to contribute", function() {
            it("reverts if it's a signer", async function() {
                try {
                    await fundr.Contribute(1234, {from: signer1_address});
                    assert.fail(null, null, "Contract should have raised.");
                } catch(error) {
                    assert.equal(error.message, "VM Exception while processing transaction: revert");
                }
            });

            it("reverts if it's not a signer", async function() {
                try {
                    await fundr.Contribute(1234, {from: contributer_address});
                    assert.fail(null, null, "Contract should have raised.");
                } catch(error) {
                    assert.equal(error.message, "VM Exception while processing transaction: revert");
                }
            });
        });

        describe("when trying to withdraw", function() {
            it("allows one signer to propose but not withdraw", async function() {
                // put some money in the account so you withdraw it
                // fundr.Withdraw(dest, amount)
            });

            it("allows both signers to withdraw", async function() {
                // actually check that money went out!
            });

            it("does not allow a non-signer to propose withdrawal", async function() {
            });

            it("does not allow the signers to withdraw more than is in the account", async function() {
            });
        });

        describe('when trying to open', function() {
            it("reverts when not one of the signers", async function() {
                try {
                    await fundr.Open({from: contributer_address});
                    assert.fail(null, null, "Contract should have raised.");
                } catch(error) {
                    assert.equal(error.message, "VM Exception while processing transaction: revert");
                }
            });

            it("allows one of the signers to propose but does not yet open", async function() {
                await fundr.Open({from: signer1_address});
                const accept = await fundr.accept.call();
                assert.equal(accept, false);
            });

            it("opens after both signers propose", async function() {
                await fundr.Open({from: signer1_address});
                await fundr.Open({from: signer2_address});
                const accept = await fundr.accept.call();
                assert.equal(accept, true);
            });

            it("opens after both signers sign in the other order", async function() {
                await fundr.Open({from: signer2_address});
                await fundr.Open({from: signer1_address});
                const accept = await fundr.accept.call();
                assert.equal(accept, true);
            });
        });
    });

    describe('when open', function() {
        beforeEach(async function () {
            await fundr.Open({from: signer1_address});
            await fundr.Open({from: signer2_address});
        });

        describe("when trying to contribute", function() {
            it("allow if it's a signer", async function() {
            });

            it("allow if it's not a signer", async function() {
                // actually check that the money went in!
                // await fundr.Contribute(0x212121210000000000000000000000000000000000000001, {from: contributer_address});
                // assert.fail()
            });

            it("revert if the pk_hash is wrong", async function() {
            });

            it("revert if pk checksum is wrong", async function() {
            });
        });

        describe("when trying to withdraw", function() {
            it("allows one signer to propose but not withdraw", async function() {
                // Must put ETH in account first
                // await fundr.Withdraw(destination_address, 1, {from: signer1_address})
            });

            it("allows both signers to withdraw", async function() {
                // Must put ETH in account first
                // await fundr.Withdraw(destination_address, 1, {from: signer1_address})
                // await fundr.Withdraw(destination_address, 1, {from: signer2_address})
            });

            it("does not allow a non-signer to propose withdrawal", async function() {
                // Must put ETH in account first
                try {
                    await fundr.Withdraw(destination_address, 1, {from: contributer_address})
                    assert.fail(null, null, "Contract should have raised.");
                } catch(error) {
                    assert.equal(error.message, "VM Exception while processing transaction: revert");
                }
            });

            it("does not allow the signers to withdraw more than is in the account", async function() {
                const contract_balance_before = await web3.eth.getBalance(fundr.address)
                const withdraw_amount = contract_balance_before.plus(1)
                try {
                    await fundr.Withdraw(destination_address, withdraw_amount, {from: signer1_address})
                    assert.fail(null, null, "Contract should have raised.");
                } catch(error) {
                    assert.equal(error.message, "VM Exception while processing transaction: revert");
                }
            });
        });

        describe('when trying to close', function() {
            it("reverts when not one of the signers", async function() {
                try {
                    await fundr.Close(destination_address, {from: contributer_address})
                    assert.fail(null, null, "Contract should have raised.");
                } catch(error) {
                    assert.equal(error.message, "VM Exception while processing transaction: revert");
                }
            });

            it("allows one of the signers to propose but does not yet close", async function() {
                await fundr.Close(destination_address, {from: signer1_address})
                const accept = await fundr.accept.call();
                assert(accept);
            });

            it("closes after both signers propose", async function() {
                // Add ETH to fundr.address
                const contract_balance_before = await web3.eth.getBalance(fundr.address);
                const dest_balance_before = await web3.eth.getBalance(destination_address);

                await fundr.Close(destination_address, {from: signer1_address});
                await fundr.Close(destination_address, {from: signer2_address});

                const accept = await fundr.accept.call();
                assert(!accept);

                const dest_balance_after = await web3.eth.getBalance(destination_address);
                assert.equal(await web3.eth.getBalance(fundr.address), 0);
                // plus and equals methods are because these are BigNumbers
                assert(dest_balance_before.plus(contract_balance_before).equals(dest_balance_after));
            });

            it("closes after both signers sign in the other order", async function() {
                // Add ETH to fundr.address
                const contract_balance_before = await web3.eth.getBalance(fundr.address)
                const dest_balance_before = await web3.eth.getBalance(destination_address)

                await fundr.Close(destination_address, {from: signer2_address})
                await fundr.Close(destination_address, {from: signer1_address})

                const accept = await fundr.accept.call();
                assert(!accept);

                const dest_balance_after = await web3.eth.getBalance(destination_address)
                assert.equal(await web3.eth.getBalance(fundr.address), 0)
                // plus and equals methods are because these are BigNumbers
                assert(dest_balance_before.plus(contract_balance_before).equals(dest_balance_after))
            });
        });

    });
});
