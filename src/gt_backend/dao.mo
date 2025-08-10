import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";

actor class DAO() {

    // --- Types ---

    public type Proposal = {
        id: Nat;
        proposer: Principal;
        title: Text;
        description: Text;
        action: Action;
        votes_for: Nat;
        votes_against: Nat;
        voters: [Principal];
        executed: Bool;
        end_time: Time.Time;
        status: ProposalStatus;
    };

    public type ProposalStatus = {
        #open;
        #passed;
        #failed;
        #executed;
    };

    public type Action = {
        #update_setting: (canister: Principal, key: Text, value: Text);
        #transfer_funds: (to: Principal, amount: Nat);
    };

    public type Vote = {
        #for;
        #against;
    };

    // --- State ---

    private stable var proposals: [Proposal] = [];
    private stable var next_proposal_id: Nat = 0;
    private stable var governance_token: ?Principal = null; // The governance token canister

    // --- Errors ---

    public type Error = {
        #unauthorized;
        #proposal_not_found;
        #already_voted;
        #proposal_not_open;
        #proposal_already_executed;
        #proposal_not_passed;
        #governance_token_not_set;
    };

    // --- Functions ---

    public func set_governance_token(token: Principal) : async Result.Result<(), Error> {
        // In a real implementation, this would be restricted to the DAO's owner.
        governance_token := ?token;
        return #ok(());
    };

    public func create_proposal(
        title: Text,
        description: Text,
        action: Action
    ) : async Result.Result<Nat, Error> {
        let proposer = msg.caller;
        let proposal: Proposal = {
            id = next_proposal_id;
            proposer = proposer;
            title = title;
            description = description;
            action = action;
            votes_for = 0;
            votes_against = 0;
            voters = [];
            executed = false;
            end_time = Time.now() + 1000000000 * 60 * 60 * 24 * 7; // 7 days
            status = #open;
        };
        proposals.push(proposal);
        let id = next_proposal_id;
        next_proposal_id += 1;
        return #ok(id);
    };

    public func vote(
        proposal_id: Nat,
        vote: Vote
    ) : async Result.Result<(), Error> {
        let voter = msg.caller;
        let proposal = proposals[proposal_id];
        if (proposal == null) {
            return #err(#proposal_not_found);
        };
        if (proposal.status != #open) {
            return #err(#proposal_not_open);
        };
        if (Array.contains(proposal.voters, voter)) {
            return #err(#already_voted);
        };

        // In a real implementation, you would check the voter's token balance
        // from the governance token canister.
        // For now, we assume each voter has 1 vote.
        let vote_power = 1;

        switch (vote) {
            case (#for) {
                proposal.votes_for += vote_power;
            };
            case (#against) {
                proposal.votes_against += vote_power;
            };
        };
        proposal.voters.push(voter);
        return #ok(());
    };

    public func execute_proposal(proposal_id: Nat) : async Result.Result<(), Error> {
        let proposal = proposals[proposal_id];
        if (proposal == null) {
            return #err(#proposal_not_found);
        };
        if (proposal.executed) {
            return #err(#proposal_already_executed);
        };
        if (proposal.status != #passed) {
            // In a real implementation, you would check the voting results here.
            // For now, we assume it passed if votes_for > votes_against.
            if (proposal.votes_for <= proposal.votes_against) {
                return #err(#proposal_not_passed);
            }
        };

        switch (proposal.action) {
            case (#update_setting(canister, key, value)) {
                // This is a placeholder for a real call to another canister.
                // You would need to define an interface for the target canister
                // and call its `update_setting` function.
                Debug.print("Executing proposal: update setting " # key # " to " # value # " on canister " # Principal.toText(canister));
            };
            case (#transfer_funds(to, amount)) {
                // This is a placeholder for a real call to the treasury.
                Debug.print("Executing proposal: transfer " # Nat.toText(amount) # " to " # Principal.toText(to));
            };
        };

        proposal.executed := true;
        proposal.status := #executed;
        return #ok(());
    };

    public query func get_proposal(proposal_id: Nat) : async ?Proposal {
        proposals[proposal_id]
    };

    public query func list_proposals() : async [Proposal] {
        proposals
    };
};
