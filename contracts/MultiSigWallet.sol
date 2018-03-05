pragma solidity 0.4.19;

contract MultiSigWallet {
    struct Proposal {
        uint256 amount;
        address signer;
        address destination;
        bool signed;
    }

    address contributor_id_signer;
    address[4] signers;
    mapping(address => Proposal) signer_proposals;

    function MultiSigWallet(
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

        // In this case it serves as initialization.
        zero_out_proposal(signers[0]);
        zero_out_proposal(signers[1]);
        zero_out_proposal(signers[2]);
        zero_out_proposal(signers[3]);
    }

    // Money comes into the wallet here.
    function contribute(bytes32 hash, bytes signed_hash) external payable {
        assert(0x0 != contributor_id_signer); // To make absolutely sure we initialized it.
        require(recover(hash, signed_hash) == contributor_id_signer); // To make sure it's signed with our key.
    }

    // Money exits the wallet here.
    function withdraw(address proposed_destination, uint256 proposed_amount) external {
        // Check that that function caller is one of the signers.
        require(signer_proposals[msg.sender].signer == msg.sender);
        // Check that this account has the funds requested (final withdrawal wouldn't work if it didn't).
        require(proposed_amount <= this.balance);
        // Check that we're not sending ETH into the ether
        require(proposed_destination != 0x0);

        // Record the fact that this signer made a request to withdraw.
        update_proposal(proposed_destination, proposed_amount);
        // Look up whether there has previous been a different signer.
        address matching_signer = find_matching_signer();
        // If another signer has made an identical request, withdraw the money.
        // If not, just exit the function quietly and wait for the second signer.
        if (matching_signer != 0x0) { actually_withdraw(); }
    }

    function update_proposal(address proposed_destination, uint256 proposed_amount) internal {
        signer_proposals[msg.sender].amount = proposed_amount;
        signer_proposals[msg.sender].destination = proposed_destination;
        signer_proposals[msg.sender].signed = true;
    }

    // Technically this finds the *first* matching signer, but since they're all zeroed out after
    // a match, there can only be one match at any given time.
    function find_matching_signer() internal view returns(address matching_signer) {
        if (is_matching_signer(signers[0])) {
            matching_signer = signers[0];
        } else if (is_matching_signer(signers[1])) {
            matching_signer = signers[1];
        } else if (is_matching_signer(signers[2])) {
            matching_signer = signers[2];
        } else if (is_matching_signer(signers[3])) {
            matching_signer = signers[3];
        }

        return matching_signer;
    }

    function actually_withdraw() internal {
        // Capture those params in local state so we can do the transfer last.
        address destination = signer_proposals[msg.sender].destination;
        uint256 amount = signer_proposals[msg.sender].amount;

        // "Unsign" all of the proposals, and clear the rest of the data just to be thorough.
        zero_out_proposal(signers[0]);
        zero_out_proposal(signers[1]);
        zero_out_proposal(signers[2]);
        zero_out_proposal(signers[3]);

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

    function is_matching_signer(address signer) internal view returns(bool) {
        return
            signer != msg.sender && // If it's not the current signer
            signer_proposals[signer].signed && // And if they have made a past proposal
            // And if their proposal matches exactly.
            signer_proposals[signer].amount == signer_proposals[msg.sender].amount &&
            signer_proposals[signer].destination == signer_proposals[msg.sender].destination;
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
        require(v == 0 || v == 1 || v == 27 || v == 28);
        if (v == 0 || v == 1) {
            v += 27;
        }
        return ecrecover(hash, v, r, s);
    }
}
