pragma solidity 0.4.18;

contract Fundraiser {
  struct Proposal {
    uint256 amount;
    address signer;
    address destination;
    bool signed;
  }

  address[4] signers;
  mapping(address => Proposal) signer_proposals;

  function Fundraiser(
    address init_signer0,
    address init_signer1,
    address init_signer2,
    address init_signer3
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

  // TODO: what about indexed?
  event LogDeposit(address receiving_address, uint amount);

  // Entry point for contributors
  function contribute(address receiving_address) external payable {
    LogDeposit(receiving_address, msg.value);
  }

  // Entry points for signers
  function withdraw(
    address proposed_destination,
    uint256 proposed_amount
  ) external {
    // Check that only one of the signers is requesting
    require(signer_proposals[msg.sender].signer == msg.sender);
    require(proposed_amount <= this.balance);

    update_proposal(proposed_destination, proposed_amount);
    maybe_perform_withdraw();
  }

  function update_proposal(
    address proposed_destination,
    uint256 proposed_amount
  ) internal {
    signer_proposals[msg.sender].amount = proposed_amount;
    signer_proposals[msg.sender].destination = proposed_destination;
    signer_proposals[msg.sender].signed = true;
  }

  function maybe_perform_withdraw() internal {
    bool two_signers;
    address first_signer;
    address second_signer;

    if (signed(0) && signed(1)) {
      two_signers = true;
      first_signer = signers[0];
      second_signer = signers[1];
    } else if (signed(0) && signed(2)) {
      two_signers = true;
      first_signer = signers[0];
      second_signer = signers[2];
    } else if (signed(0) && signed(3)) {
      two_signers = true;
      first_signer = signers[0];
      second_signer = signers[3];
    } else if (signed(1) && signed(2)) {
      two_signers = true;
      first_signer = signers[1];
      second_signer = signers[2];
    } else if (signed(1) && signed(3)) {
      two_signers = true;
      first_signer = signers[1];
      second_signer = signers[3];
    } else if (signed(2) && signed(3)) {
      two_signers = true;
      first_signer = signers[2];
      second_signer = signers[3];
    }

    // If not, just exit the function quietly and wait for the second signer.
    if (two_signers) {
      // The two signers must agree exactly.
      require(signer_proposals[first_signer].amount == signer_proposals[second_signer].amount);
      require(signer_proposals[first_signer].destination == signer_proposals[second_signer].destination);

      signer_proposals[signers[0]].signed = false;
      signer_proposals[signers[1]].signed = false;
      signer_proposals[signers[2]].signed = false;
      signer_proposals[signers[3]].signed = false;

      signer_proposals[first_signer].destination.transfer(signer_proposals[first_signer].amount);

      signer_proposals[signers[0]].amount = 0;
      signer_proposals[signers[1]].amount = 0;
      signer_proposals[signers[2]].amount = 0;
      signer_proposals[signers[3]].amount = 0;

      signer_proposals[signers[0]].destination = 0x0;
      signer_proposals[signers[1]].destination = 0x0;
      signer_proposals[signers[2]].destination = 0x0;
      signer_proposals[signers[3]].destination = 0x0;
    }
  }

  function signed(uint index) internal view returns(bool) {
    return signer_proposals[signers[index]].signed;
  }
}
