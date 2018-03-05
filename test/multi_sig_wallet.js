const MultiSigWallet = artifacts.require("MultiSigWallet")

function toHex(str) {
    let hex = '';
    for (var i = 0; i < str.length; i++) {
        hex += '' + str.charCodeAt(i).toString(16)
    }
    return '0x' + hex
}

async function assertRaisedWithMessage(message, raising_code) {
    try {
        await raising_code()
    } catch(error) {
        assert.equal(error.message, message)
        return
    }
    assert.fail(null, null, "Contract should have raised.")
}

function assertReverts(reverting_code) {
    assertRaisedWithMessage("VM Exception while processing transaction: revert", reverting_code)
}

contract('MultiSigWallet', function(accounts) {
    let wallet
    let hash_signer_address
    let destination_address

    async function testWithdraw(signer1, signer2, amount_withdrawn=1) {
        const balance_before = await web3.eth.getBalance(wallet.address)
        const dest_balance_before = await web3.eth.getBalance(destination_address)

        await wallet.withdraw(destination_address, amount_withdrawn, {from: signer1})
        await wallet.withdraw(destination_address, amount_withdrawn, {from: signer2})

        const balance_after = await web3.eth.getBalance(wallet.address)
        const dest_balance_after = await web3.eth.getBalance(destination_address)

        // Then make sure that amount was withdrawn
        // plus and equals methods are because these are BigNumbers
        assert(balance_after.plus(amount_withdrawn).equals(balance_before), "Amount was not withdrawn!")
        assert(dest_balance_before.plus(amount_withdrawn).equals(dest_balance_after), "Amount was not deposited!")
    }

    function makeContribution(contributer_address, amount_sent, signer_address=hash_signer_address) {
        // The id we store in the portal database
        const contributer_id = "idunnolikeanemail@something.com"

        // The signed version
        const signed_id = web3.eth.sign(signer_address, toHex(contributer_id))

        // The thing that the signed version can be shown equivalent to
        const prefixed_id = `\x19Ethereum Signed Message:\n${contributer_id.length}${contributer_id}`
        const contributer_hash = web3.sha3(prefixed_id)

        return wallet.contribute(
            contributer_hash,
            signed_id,
            {from: contributer_address, value: amount_sent}
        )
    }

    function makeInitialContribution(contributer_address, amount_sent=1) {
        return makeContribution(contributer_address, amount_sent)
    }

    const all_signer_dups = [
        [1, 1, 1, 1],

        [1, 1, 1, 2],
        [1, 1, 2, 1],
        [1, 2, 1, 1],
        [2, 1, 1, 1],

        [1, 1, 2, 2],
        [1, 2, 1, 2],
        [2, 1, 1, 2],
        [1, 2, 2, 1],
        [2, 1, 2, 1],
        [2, 2, 1, 1],

        [1, 1, 2, 3],
        [1, 2, 1, 3],
        [1, 2, 3, 1],
        [2, 1, 1, 3],
        [2, 1, 3, 1],
        [2, 3, 1, 1],
    ]

    const all_signer_pairs = [
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

    for (let quad of all_signer_dups) {
        it("reverts when deployed with duplicate signers", function() {
            assertReverts(function() {
                return MultiSigWallet.new(
                    accounts[quad[0]], accounts[quad[1]], accounts[quad[2]], accounts[quad[3]]
                )
            })
        })
    }

    describe("on successful deploy", function() {
        let signers
        let contributer_address

        beforeEach(async function () {
            signers = [
                accounts[1],
                accounts[2],
                accounts[3],
                accounts[4],
            ]

            hash_signer_address = accounts[5]

            wallet = await MultiSigWallet.new(...signers, hash_signer_address)

            contributer_address = accounts[6]
            destination_address = accounts[7]
        })

        it("reverts when ether is sent to it with no data", function() {
            assertReverts(function() {
                return wallet.sendTransaction({from: contributer_address, value: 1})
            })
        })

        describe("when trying to contribute", function() {
            it("allow if it's a signer", async function() {
                const balance_before = await web3.eth.getBalance(wallet.address)
                const amount_sent = 1

                await makeContribution(signers[0], amount_sent)

                const balance_after = await web3.eth.getBalance(wallet.address)
                assert(balance_after.equals(balance_before.plus(amount_sent)), "Contribution not found in contract address.")
            })

            it("allow if it's not a signer", async function() {
                const balance_before = await web3.eth.getBalance(wallet.address)
                const amount_sent = 1

                await makeContribution(contributer_address, amount_sent)

                const balance_after = await web3.eth.getBalance(wallet.address)
                assert(balance_after.equals(balance_before.plus(amount_sent)), "Contribution not found in contract address.")
            })

            it("reverts if the signed data is junk", function() {
                assertReverts(function() {
                    return wallet.contribute(
                        web3.toHex("0x1234"),
                        web3.toHex("0x1234"),
                        {from: contributer_address}
                    )
                })
            })

            it("reverts if the hash is signed by the wrong key", function() {
                assertReverts(function() {
                    return makeContribution(contributer_address, amount_sent, contributer_address)
                })
            })

            // Seems like maybe we don't need an event?
            it.skip("emits a LogDeposit event on success", async function() {
                const amount = 1
                const receiving_address = '0x0000000000000000000000000000000000000000'

                let passes = false

                const log_deposit = wallet.LogDeposit()
                log_deposit.watch(function(err, result) {
                    if (err) {
                        assert.fail(err.message)
                    }
                    assert.equal(result.args.receiving_address, receiving_address)
                    assert(result.args.amount.equals(amount), `${result.args.amount} does not equal ${amount}`)
                    passes = true
                })

                await wallet.contribute(receiving_address, {from: contributer_address, value: amount})

                await log_deposit.stopWatching()
                assert(passes, "LogDeposit event was not emitted.")
            })

            // Seems like maybe we don't need an event?
            it.skip("does not emit a LogDeposit event on failure")
        })

        describe("when trying to withdraw", function() {
            beforeEach(function () {
                return makeInitialContribution(contributer_address)
            })

            it("allows one signer to propose but not withdraw", async function() {
                const balance_before = await web3.eth.getBalance(wallet.address)
                await wallet.withdraw(destination_address, 1, {from: signers[0]})
                const balance_after = await web3.eth.getBalance(wallet.address)
                assert(balance_after.equals(balance_before), `Contract balance has changed from ${balance_before} to ${balance_after}.`)
            })

            it("does not allow one signer to withdraw", async function() {
                const balance_before = await web3.eth.getBalance(wallet.address)
                await wallet.withdraw(destination_address, 1, {from: signers[0]})
                await wallet.withdraw(destination_address, 1, {from: signers[0]})
                const balance_after = await web3.eth.getBalance(wallet.address)
                assert(balance_after.equals(balance_before), `Contract balance has changed from ${balance_before} to ${balance_after}.`)
            })

            for (let pair of all_signer_pairs) {
                it("allows all possible signer pairs to withdraw", function() {
                    testWithdraw(signers[pair[0]], signers[pair[1]])
                })
            }

            it("allows withdrawal twice", async function() {
                await testWithdraw(signers[0], signers[1])
                await makeContribution(contributer_address, 1)
                await testWithdraw(signers[1], signers[0])
            })

            it("does not allow a non-signer to propose withdrawal", function() {
                assertReverts(function() {
                    return wallet.withdraw(destination_address, 1, {from: contributer_address})
                })
            })

            it("does not allow the signers to withdraw more than is in the account", async function() {
                const contract_balance_before = await web3.eth.getBalance(wallet.address)
                // plus and equals methods are because these are BigNumbers
                const withdraw_amount = contract_balance_before.plus(1)
                assertReverts(function() {
                    return wallet.withdraw(destination_address, withdraw_amount, {from: signers[0]})
                })
            })

            it("does not allow withdrawing a negative amount", function() {
                // I think this fails on the javascript side, because the contract function takes a uint, but it's worth testing.
                assertReverts(function() {
                    return testWithdraw(signers[0], signers[1], -1)
                })
            })

            it("does not allow withdrawing to the zero address", function () {
                assertReverts(function() {
                    return wallet.withdraw(0x0, 1, {from: signers[0]})
                })
            })

            it("allows a proposal to override the former one", async function () {
                await wallet.withdraw(destination_address, 0, {from: signers[0]})
                return testWithdraw(signers[1], signers[2], 1)
            })
        })
    })
})
