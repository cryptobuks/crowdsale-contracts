pragma solidity 0.4.19;

contract Fundraiser {
    struct Proposal {
        uint256 amount;
        address signer;
        address destination;
        bool signed;
    }

    address contributor_id_signer;
    address[4] signers;
    mapping(address => Proposal) signer_proposals;

    function Fundraiser(
        address init_signer0,
        address init_signer1,
        address init_signer2,
        address init_signer3,
        address init_id_signer
    ) public {
        // All of the addresses need to be distinct
        require(
            init_signer0 != init_signer1 &&
            init_signer0 != init_signer2 &&
            init_signer0 != init_signer3 &&
            init_signer1 != init_signer2 &&
            init_signer1 != init_signer3 &&
            init_signer2 != init_signer3
        );
        require(
            init_id_signer != init_signer0 &&
            init_id_signer != init_signer1 &&
            init_id_signer != init_signer2 &&
            init_id_signer != init_signer3
        );

        contributor_id_signer = init_id_signer;

        signers = [init_signer0, init_signer1, init_signer2, init_signer3];

        zero_out_proposal(signers[0]);
        zero_out_proposal(signers[1]);
        zero_out_proposal(signers[2]);
        zero_out_proposal(signers[3]);
    }

    // Entry point for contributors
    function contribute(bytes32 hash, bytes signed_hash) external payable {
        assert(0x0 != contributor_id_signer); // To make absolutely sure we initialized it.
        require(recover(hash, signed_hash) == contributor_id_signer); // To make sure it's signed with our key.
    }

    // Entry points for signers
    function withdraw(address proposed_destination, uint256 proposed_amount) external {
        // Check that only one of the signers is requesting
        require(signer_proposals[msg.sender].signer == msg.sender);
        require(proposed_amount <= this.balance);
        require(proposed_destination != 0x0);

        update_proposal(proposed_destination, proposed_amount);
        maybe_perform_withdraw();
    }

    function update_proposal(address proposed_destination, uint256 proposed_amount) internal {
        signer_proposals[msg.sender].amount = proposed_amount;
        signer_proposals[msg.sender].destination = proposed_destination;
        signer_proposals[msg.sender].signed = true;
    }

    function maybe_perform_withdraw() internal {
        bool two_signers;
        address first_signer = msg.sender;
        address second_signer;

        // Figure out which if another signed
        if (also_signed(0)) {
            two_signers = true;
            second_signer = signers[0];
        } else if (also_signed(1)) {
            two_signers = true;
            second_signer = signers[1];
        } else if (also_signed(2)) {
            two_signers = true;
            second_signer = signers[2];
        } else if (also_signed(3)) {
            two_signers = true;
            second_signer = signers[3];
        }

        // If not, just exit the function quietly and wait for the second signer.
        if (two_signers) { replace_or_withdraw(first_signer, second_signer); }
    }

    function replace_or_withdraw(address first_signer, address second_signer) internal {
        // To withdraw, the two signers must agree exactly.
        if (
            signer_proposals[first_signer].amount == signer_proposals[second_signer].amount &&
            signer_proposals[first_signer].destination == signer_proposals[second_signer].destination
        ) {
            actually_withdraw(first_signer, second_signer);
        } else {
            zero_out_proposal(second_signer);
        }
    }

    function actually_withdraw(address first_signer, address second_signer) internal {
        // Capture those params in local state so we can do the transfer last.
        address destination = signer_proposals[first_signer].destination;
        uint256 amount = signer_proposals[first_signer].amount;

        // "Unsign" all of the proposals, and clear the rest of the data just to be thorough.
        zero_out_proposal(first_signer);
        zero_out_proposal(second_signer);

        // Two of these we just zeroed, and the other two better be empty as well.
        assert_proposal_empty(signers[0]);
        assert_proposal_empty(signers[1]);
        assert_proposal_empty(signers[2]);
        assert_proposal_empty(signers[3]);

        // Actually withdraw the money.
        destination.transfer(amount);
    }


    function zero_out_proposal(address signer) internal {
        signer_proposals[signer] = Proposal({
            amount: 0,
            signer: signer,
            destination: 0x0,
            signed: false
        });
    }

    function assert_proposal_empty(address signer) internal view {
        assert(
            signer_proposals[signer].signed == false &&
            signer_proposals[signer].amount == 0 &&
            signer_proposals[signer].destination == 0x0 &&
            signer_proposals[signer].signer == signer // I mean, this is an assert, so it better.
        );
    }

    function also_signed(uint index) internal view returns(bool) {
        return signer_proposals[signers[index]].signed && signers[index] != msg.sender;
    }

    // For reference https://github.com/OpenZeppelin/zeppelin-solidity/blob/815d9e1/contracts/ECRecovery.sol
    function recover(bytes32 hash, bytes sig) internal pure returns (address) {
        // Check the signature length
        require(sig.length == 65);

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Must drop into assembly to access the bytes.
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        // Geth signing causes these values; ecrecover expects 27 or 28.
        require(v == 0 || v == 1);
        v += 27;
        return ecrecover(hash, v, r, s);
    }
}
