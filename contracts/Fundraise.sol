pragma solidity ^0.4.19;

contract Fundraiser {

  /* State */

  address signer1;
  address signer2;
  bool public accept; // are contributions accepted

  enum Action {
    None,
    Withdraw,
    Close,
    Open
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
    accept = false; // must call Open first
    signer1 = init_signer1;
    signer2 = init_signer2;
    signer1_proposal.action = Action.None;
    signer2_proposal.action = Action.None;
  }

  /* no default action, in case people forget to send their data
     or in case they use a buggy app that forgets to send the data */
  function () public {
    revert();
  }

  /* Entry point for contributors */

  event Deposit (
                 bytes20 tezos_pk_hash,
                 uint amount
                 );

  function Contribute(bytes24 tezos_pkh_and_chksum) public payable {
    // Don't accept contributions if fundraiser closed
    require(accept);
    bytes20 tezos_pk_hash = bytes20(tezos_pkh_and_chksum);
    /* shift left 20 bytes to extract checksum */
    bytes4 expected_chksum = bytes4(tezos_pkh_and_chksum << 160);
    bytes4 chksum = bytes4(sha256(sha256(tezos_pk_hash)));
    /* revert transaction if the checksum cannot be verified */
    require(chksum == expected_chksum);
    Deposit(tezos_pk_hash, msg.value);
  }

  /* Entry points for signers */

  function Withdraw(address proposed_destination,
                    uint256 proposed_amount) public {
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
    MaybePerformWithdraw();
  }

  function Close(address proposed_destination) public {
    /* check that only one of the signers is requesting */
    require(msg.sender == signer1 || msg.sender == signer2);
    /* update action */
    if (msg.sender == signer1) {
      signer1_proposal.action = Action.Close;
      signer1_proposal.destination = proposed_destination;
    } else if (msg.sender == signer2) {
      signer2_proposal.action = Action.Close;
      signer2_proposal.destination = proposed_destination;
    } else { assert(false); }
    /* perform action */
    MaybePerformClose();
  }

  function Open() public {
    /* check that only one of the signers is requesting */
    require(msg.sender == signer1 || msg.sender == signer2);
    /* update action */
    if (msg.sender == signer1) {
      signer1_proposal.action = Action.Open;
    } else if (msg.sender == signer2) {
      signer2_proposal.action = Action.Open;
    } else { assert(false); }
    /* perform action */
    MaybePerformOpen();
  }

  function MaybePerformWithdraw() internal {
    if (signer1_proposal.action == Action.Withdraw
        && signer2_proposal.action == Action.Withdraw
        && signer1_proposal.amount == signer2_proposal.amount
        && signer1_proposal.destination == signer2_proposal.destination) {
      signer1_proposal.action = Action.None;
      signer2_proposal.action = Action.None;
      signer1_proposal.destination.transfer(signer1_proposal.amount);
    }
  }

  function MaybePerformClose() internal {
    if (signer1_proposal.action == Action.Close
        && signer2_proposal.action == Action.Close
        && signer1_proposal.destination == signer2_proposal.destination) {
      accept = false;
      signer1_proposal.destination.transfer(this.balance);
    }
  }

  function MaybePerformOpen() internal {
    if (signer1_proposal.action == Action.Open
        && signer2_proposal.action == Action.Open) {
      accept = true;
    }
  }
}
