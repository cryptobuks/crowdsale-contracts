var Fundraiser = artifacts.require("Fundraiser")

async function testWithdraw(signer1, signer2) {
    amount_withdrawn = 1

    balance_before = await web3.eth.getBalance(fundr.address)
    dest_balance_before = await web3.eth.getBalance(destination_address)

    await fundr.withdraw(destination_address, amount_withdrawn, {from: signer1})
    await fundr.withdraw(destination_address, amount_withdrawn, {from: signer2})

    balance_after = await web3.eth.getBalance(fundr.address)
    dest_balance_after = await web3.eth.getBalance(destination_address)

    // Then make sure that amount was withdrawn
    // plus and equals methods are because these are BigNumbers
    assert(balance_after.plus(amount_withdrawn).equals(balance_before), "Amount was not withdrawn!")
    assert(dest_balance_before.plus(amount_withdrawn).equals(dest_balance_after), "Amount was not deposited!")
}

contract('Fundraiser', function(accounts) {
    let all_signer_pairs = [
        [0, 1],
        [0, 2],
        [0, 3],
        [1, 0],
        [1, 2],
        [1, 3],
        [2, 0],
        [2, 1],
        [2, 3],
        [3, 0],
        [3, 1],
        [3, 2],
    ]

    beforeEach(async function () {
        signers = [
            accounts[1],
            accounts[2],
            accounts[3],
            accounts[4],
        ]

        fundr = await Fundraiser.new(...signers)

        contributer_address = accounts[5]
        destination_address = accounts[6]
    })

    it("reverts when ether is sent to it with no data", async function() {
        try {
            await fundr.sendTransaction({from: contributer_address, value: 1})
        } catch(error) {
            assert.equal(error.message, "VM Exception while processing transaction: revert")
            return
        }
        assert.fail(null, null, "Contract should have raised.")
    })

    describe("when trying to contribute", function() {
        it("allow if it's a signer", async function() {
            const balance_before = await web3.eth.getBalance(fundr.address)
            const amount_sent = 1

            await fundr.contribute(
                "0x0000000000000000000000000000000000000000",
                {from: signers[0], value: amount_sent}
            )

            const balance_after = await web3.eth.getBalance(fundr.address)
            assert(balance_after.equals(balance_before.plus(amount_sent)))
        })

        it("allow if it's not a signer", async function() {
            const balance_before = await web3.eth.getBalance(fundr.address)
            const amount_sent = 1

            await fundr.contribute(
                "0x0000000000000000000000000000000000000000",
                {from: contributer_address, value: amount_sent}
            )

            const balance_after = await web3.eth.getBalance(fundr.address)
            assert(balance_after.equals(balance_before.plus(amount_sent)))
        })

        // Skipping because the contract abstraction seems to pad the address with zeros, making it valid.
        // We should figure out a way to send directly to the contract like a wallet would.
        it.skip("revert if address is malformed", async function() {
            try {
                await fundr.contribute(
                    "0x1234",
                    {from: contributer_address}
                )
            } catch(error) {
                assert.equal(error.message, "Invalid array length")
                return
            }
            assert.fail(null, null, "Contract should have raised.")
        })

        it.skip("emits a LogDeposit event on success")
        it.skip("does not emit a LogDeposit event on failure")
    })

    describe("when trying to withdraw", function() {
        beforeEach(async function () {
            await fundr.contribute(
                "0x0000000000000000000000000000000000000000",
                {from: contributer_address, value: 1}
            )
        })

        it("allows one signer to propose but not withdraw", async function() {
            const balance_before = await web3.eth.getBalance(fundr.address)
            await fundr.withdraw(destination_address, 1, {from: signers[0]})
            const balance_after = await web3.eth.getBalance(fundr.address)

            assert(balance_after.equals(balance_before))
        })

        for (let pair of all_signer_pairs) {
            it("allows all possible signer pairs to withdraw", async function() {
                testWithdraw(signers[pair[0]], signers[pair[1]])
            })
        }

        it("allows withdrawl twice", async function() {
            await testWithdraw(signers[0], signers[1])

            await fundr.contribute(
                "0x0000000000000000000000000000000000000000",
                {from: contributer_address, value: 1}
            )

            await testWithdraw(signers[1], signers[0])
        })

        it("does not allow a non-signer to propose withdrawal", async function() {
            try {
                await fundr.withdraw(destination_address, 1, {from: contributer_address})
            } catch(error) {
                assert.equal(error.message, "VM Exception while processing transaction: revert")
                return
            }
            assert.fail(null, null, "Contract should have raised.")
        })

        it("does not allow the signers to withdraw more than is in the account", async function() {
            const contract_balance_before = await web3.eth.getBalance(fundr.address)
            // plus and equals methods are because these are BigNumbers
            const withdraw_amount = contract_balance_before.plus(1)
            try {
                await fundr.withdraw(destination_address, withdraw_amount, {from: signers[0]})
            } catch(error) {
                assert.equal(error.message, "VM Exception while processing transaction: revert")
                return
            }
            assert.fail(null, null, "Contract should have raised.")
        })
    })
})
