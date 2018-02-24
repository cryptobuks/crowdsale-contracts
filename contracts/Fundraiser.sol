pragma solidity 0.4.18;

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
      init_signer0 != init_signer1
      && init_signer0 != init_signer2
      && init_signer0 != init_signer3
      && init_signer1 != init_signer2
      && init_signer1 != init_signer3
      && init_signer2 != init_signer3
    );
    require(
      init_id_signer != init_signer0
      && init_id_signer != init_signer1
      && init_id_signer != init_signer2
      && init_id_signer != init_signer3
    );

    contributor_id_signer = init_id_signer;

    signers = [init_signer0, init_signer1, init_signer2, init_signer3];

    signer_proposals[init_signer0] = Proposal({
      amount: 0,
      signer: init_signer0,
      destination: 0x0,
      signed: false
    });

    signer_proposals[init_signer1] = Proposal({
      amount: 0,
      signer: init_signer1,
      destination: 0x0,
      signed: false
    });

    signer_proposals[init_signer2] = Proposal({
      amount: 0,
      signer: init_signer2,
      destination: 0x0,
      signed: false
    });

    signer_proposals[init_signer3] = Proposal({
      amount: 0,
      signer: init_signer3,
      destination: 0x0,
      signed: false
    });
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
    if (two_signers) {
      // The two signers must agree exactly.
      require(signer_proposals[first_signer].amount == signer_proposals[second_signer].amount);
      require(signer_proposals[first_signer].destination == signer_proposals[second_signer].destination);

      // Capture those params in local state so we can do the transfer last.
      address destination = signer_proposals[first_signer].destination;
      uint256 amount = signer_proposals[first_signer].amount;

      // "Unsign" all of the proposals.
      signer_proposals[signers[0]].signed = false;
      signer_proposals[signers[1]].signed = false;
      signer_proposals[signers[2]].signed = false;
      signer_proposals[signers[3]].signed = false;

      // Zero out the rest of the proposal, just to be thorough.
      signer_proposals[signers[0]].amount = 0;
      signer_proposals[signers[1]].amount = 0;
      signer_proposals[signers[2]].amount = 0;
      signer_proposals[signers[3]].amount = 0;

      signer_proposals[signers[0]].destination = 0x0;
      signer_proposals[signers[1]].destination = 0x0;
      signer_proposals[signers[2]].destination = 0x0;
      signer_proposals[signers[3]].destination = 0x0;

      // Actually withdraw the money.
      destination.transfer(amount);
    }
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
