pragma solidity 0.4.18;

contract Fundraiser {

  /* State */
  address signer1;
  address signer2;

  struct Proposal {
    bool signed;
    address destination;
    uint256 amount;
  }
  
  Proposal signer1_proposal;
  Proposal signer2_proposal;

  /* Constructor, choose signers. Those cannot be changed */
  function Fundraiser(address init_signer1,
                      address init_signer2) public {
    signer1 = init_signer1;
    signer2 = init_signer2;
    signer1_proposal.signed = false;
    signer2_proposal.signed = false;
  }

  /* Entry point for contributors */
  event LogDeposit(address receiving_address, uint amount);

  function contribute(address receiving_address) external payable {
    LogDeposit(receiving_address, msg.value);
  }

  /* Entry points for signers */
  function withdraw(address proposed_destination,
                    uint256 proposed_amount) external {
    /* check that only one of the signers is requesting */
    require(msg.sender == signer1 || msg.sender == signer2);
    /* check amount */
    require(proposed_amount <= this.balance);

    /* update action */
    if (msg.sender == signer1) {
      signer1_proposal.signed = true;
      signer1_proposal.destination = proposed_destination;
      signer1_proposal.amount = proposed_amount;
    } else if (msg.sender == signer2) {
      signer2_proposal.signed = true;
      signer2_proposal.destination = proposed_destination;
      signer2_proposal.amount = proposed_amount;
    } else { assert(false); }
    /* perform action */
    maybe_perform_withdraw();
  }

  function maybe_perform_withdraw() internal {
    if (signer1_proposal.signed == true
        && signer2_proposal.signed == true
        && signer1_proposal.amount == signer2_proposal.amount
        && signer1_proposal.destination == signer2_proposal.destination) {
      signer1_proposal.signed = false;
      signer2_proposal.signed = false;
      signer1_proposal.destination.transfer(signer1_proposal.amount);
    }
  }
}
