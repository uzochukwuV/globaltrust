import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import TrieSet "mo:base/TrieSet";
import Nat64 "mo:base/Nat64";
import Float "mo:base/Float";

// Imported Canisters
import IdentityCanister "canister:identity";
import RwaNftCanister "canister:rwa_nft";
...
    let rwa_nft = RwaNftCanister.RwaNft(admin, /*verificationOrchestrator=*/admin);

    // Phase 8: update facade to match new API fully. Temporarily provide basic wrappers:

    public shared(msg) func mintRwaNft(
        to: Principal,
        metadata: RwaNftCanister.RwaNftMetadata,
    ): async Result.Result<RwaNftCanister.TokenId, RwaNftCanister.Error> {
        await rwa_nft.mintRwaNft({to = to; metadata = metadata})
    };

    public shared(msg) func setLien(tokenId: Nat, active: Bool): async Result.Result<(), RwaNftCanister.Error> {
        await rwa_nft.setLien(tokenId, active)
    };

    public shared(msg) func setCollateralized(tokenId: Nat, active: Bool): async Result.Result<(), RwaNftCanister.Error> {
        await rwa_nft.setCollateralized(tokenId, active)
    };

    public shared(msg) func freeze(tokenId: Nat): async Result.Result<(), RwaNftCanister.Error> {
        await rwa_nft.freeze(tokenId)
    };

    public shared(msg) func unfreeze(tokenId: Nat): async Result.Result<(), RwaNftCanister.Error> {
        await rwa_nft.unfreeze(tokenId)
    };

    public shared(msg) func safeTransfer(
        from: Principal,
        to: Principal,
        tokenId: Nat
    ): async Result.Result<(), RwaNftCanister.Error> {
        await rwa_nft.safeTransfer({from=from; to=to; tokenId=tokenId})
    };

    public query func ownerOf(tokenId: Nat): async Result.Result<Principal, RwaNftCanister.Error> {
        await rwa_nft.ownerOf(tokenId)
    };

    public query func tokenMetadata(tokenId: Nat): async Result.Result<RwaNftCanister.RwaNftMetadata, RwaNftCanister.Error> {
        await rwa_nft.tokenMetadata(tokenId)
    };

    public query func totalSupply(): async Nat {
        await rwa_nft.totalSupply()
    };

    public query func getCertifiedMetadata(tokenId: Nat): async ?RwaNftCanister.CertifiedMetadata {
        await rwa_nft.getCertifiedMetadata(tokenId)
    };

    public shared (msg) func addVerifiableCredential(
        credentialType: Text,
        issuer: Text,
        issuedAt: Nat,
        expirationDate: ?Nat,
        credentialHash: Text
    ): async Result.Result<IdentityCanister.VerifiableCredential, IdentityCanister.Errors> {
        await identity_verifier.addVerifiableCredential(credentialType, issuer, issuedAt, expirationDate, credentialHash)
    };

    public shared query func checkVerified(user: Principal): async Bool {
        await identity_verifier.checkVerified(user)
    };

    public query func getIdentity(id: Principal): async ?IdentityCanister.Identity {
        await identity_verifier.getIdentity(id)
    };

    // Asset Tokenization Methods
    public shared(msg) func mintRwa(
        rwa: Rwa.Rwa,
        fractionalShares: Nat
    ): async AssetTokenizationCanister.MintResult {
        await rwa_token.mintRwa(rwa, fractionalShares)
    };

    public shared(msg) func buyShares(rwaId: Nat, amount: Nat): async Result.Result<Nat, AssetTokenizationCanister.Errors> {
        await rwa_token.buyShares(rwaId, amount)
    };

    public query func getTokenInfo(tokenId: Nat): async Result.Result<AssetTokenizationCanister.TokenInfoExt, AssetTokenizationCanister.Errors> {
        await rwa_token.getTokenInfo(tokenId)
    };

    // RWA Verifier Methods
    public shared(msg) func submitRwa(
        rwa: Rwa.Rwa,
        document_text: Text,
        ipfs_hash: ?Text,
        file_type: ?Text,
        file_size: ?Nat,
        submission_notes: ?Text
    ) : async RwaVerifier.SubmissionResponse {
        await rwa_verifier.submitRwa(rwa, document_text, ipfs_hash, file_type, file_size, submission_notes)
    };

    public query func getSubmissionById(submission_id: Text) : async ?Rwa.RwaSubmission {
        await rwa_verifier.getSubmissionById(submission_id)
    };

    // Lending/Borrowing Methods
    public shared (msg) func submitLoanApplication(application : LendingCanister.LoanApplication) : async LendingCanister.LoanResponse {
        await lending_borrowing.submitLoanApplication(application)
    };

    public shared (msg) func fundLoan(loan_id : Text) : async Result.Result<Text, Text> {
        await lending_borrowing.fundLoan(loan_id)
    };

    public query func getLoanById(loan_id : Text) : async ?LendingCanister.LoanRequest {
        await lending_borrowing.getLoanById(loan_id)
    };

    // Marketplace Methods
    public shared(msg) func createListing(
        submission_id: Text,
        price: Nat,
        listing_type: MarketplaceCanister.ListingType,
        auction_duration: ?Nat64,
        reserve_price: ?Nat
    ) : async MarketplaceCanister.ListingResponse {
        await rwa_marketplace.createListing(submission_id, price, listing_type, auction_duration, reserve_price)
    };

    public shared(msg) func submitOffer(listing_id: Text, amount: Nat) : async Result.Result<Text, Text> {
        await rwa_marketplace.submitOffer(listing_id, amount)
    };

    public query func getListingById(listing_id: Text) : async ?MarketplaceCanister.RwaListing {
        await rwa_marketplace.getListingById(listing_id)
    };

    // AI Verifier Methods
    public func verifyDocument(submission_id: Text, rwa: Rwa.Rwa, document_text: Text) : async Result.Result<Rwa.AIVerificationResult, Text> {
        await ai_verifier.verifyDocument(submission_id, rwa, document_text)
    };

    public shared(msg) func crossReferenceWithExternalAPI(url: Text) : async Result.Result<Text, Text> {
        await ai_verifier.crossReferenceWithExternalAPI(url)
    };

    // Cross-Chain Manager Methods
    public shared(msg) func verifyNftOwner(
        chain: Text,
        contractAddress: Text,
        tokenId: Text
    ) : async Result.Result<Text, Text> {
        await cross_chain_manager.verifyNftOwner(chain, contractAddress, tokenId)
    };

    public query func getCkbtcBalance(owner: Principal) : async Nat {
        await cross_chain_manager.getCkbtcBalance(owner)
    };

    public func transferCkbtc(to: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        await cross_chain_manager.transferCkbtc(to, amount)
    };

    public query func getCkethBalance(owner: Principal) : async Nat {
        await cross_chain_manager.getCkethBalance(owner)
    };

    public func transferCketh(to: Principal, amount: Nat) : async Result.Result<Nat, Text> {
        await cross_chain_manager.transferCketh(to, amount)
    };

    // DAO Methods
    public func set_governance_token(token: Principal) : async Result.Result<(), DAO.Error> {
        await dao.set_governance_token(token)
    };

    public func create_proposal(
        title: Text,
        description: Text,
        action: DAO.Action
    ) : async Result.Result<Nat, DAO.Error> {
        await dao.create_proposal(title, description, action)
    };

    public func vote(
        proposal_id: Nat,
        vote: DAO.Vote
    ) : async Result.Result<(), DAO.Error> {
        await dao.vote(proposal_id, vote)
    };

    public func execute_proposal(proposal_id: Nat) : async Result.Result<(), DAO.Error> {
        await dao.execute_proposal(proposal_id)
    };

    public query func get_proposal(proposal_id: Nat) : async ?DAO.Proposal {
        await dao.get_proposal(proposal_id)
    };

    public query func list_proposals() : async [DAO.Proposal] {
        await dao.list_proposals()
    };
};
