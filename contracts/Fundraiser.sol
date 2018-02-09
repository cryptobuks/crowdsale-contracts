pragma solidity 0.4.18;

contract Fundraiser {

  /* State */
  address signer1;
  address signer2;

  enum Action {
    None,
    Withdraw
  }
  
  struct Proposal {
    Action action;
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
    signer1_proposal.action = Action.None;
    signer2_proposal.action = Action.None;
  }

  /* Entry point for contributors */
  event LogDeposit (bytes20 flamingo_pk_hash, uint amount);

  function contribute(bytes24 flamingo_pkh_and_chksum) external payable {
    // Don't accept contributions if fundraiser closed
    bytes20 flamingo_pk_hash = bytes20(flamingo_pkh_and_chksum);

    /* shift left 20 bytes to extract checksum */
    bytes4 expected_chksum = bytes4(flamingo_pkh_and_chksum << 8*20);
    bytes4 chksum = bytes4(sha256(sha256(flamingo_pk_hash)));

    /* revert transaction if the checksum cannot be verified */
    require(chksum == expected_chksum);
    LogDeposit(flamingo_pk_hash, msg.value);
  }

  /* Entry points for signers */
  function withdraw(address proposed_destination,
                    uint256 proposed_amount) external {
    /* check amount */
    require(proposed_amount <= this.balance);
    /* check that only one of the signers is requesting */
    require(msg.sender == signer1 || msg.sender == signer2);

    /* update action */
    if (msg.sender == signer1) {
      signer1_proposal.action = Action.Withdraw;
      signer1_proposal.destination = proposed_destination;
      signer1_proposal.amount = proposed_amount;
    } else if (msg.sender == signer2) {
      signer2_proposal.action = Action.Withdraw;
      signer2_proposal.destination = proposed_destination;
      signer2_proposal.amount = proposed_amount;
    } else { assert(false); }
    /* perform action */
    maybe_perform_withdraw();
  }

  function maybe_perform_withdraw() internal {
    if (signer1_proposal.action == Action.Withdraw
        && signer2_proposal.action == Action.Withdraw
        && signer1_proposal.amount == signer2_proposal.amount
        && signer1_proposal.destination == signer2_proposal.destination) {
      signer1_proposal.action = Action.None;
      signer2_proposal.action = Action.None;
      signer1_proposal.destination.transfer(signer1_proposal.amount);
    }
  }
}
