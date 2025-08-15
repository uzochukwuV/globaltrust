/**
 * Module     : main.mo
 * Copyright  : 2025 YourTeam
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : YourTeam <your.email@example.com>
 * Stability  : Experimental
 * Description: Canister for on-chain identity verification with document storage
 */

import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import CertifiedData "mo:base/CertifiedData";
import Types "./types";

shared ({ caller = admin }) actor class IdentityVerifier(admin: Principal) = this {
    type Identity = Types.Identity;
    type VerifiableCredential = Types.VerifiableCredential;
    type Response = Types.Response;
    type Errors = Types.Errors;

    // Default expiration for authentication sessions (5 minutes in nanoseconds)
    private let DEFAULT_EXPIRATION_NANOSECONDS: Nat = 5 * 60 * 1_000_000_000;

    // Stable storage for identities
    private stable var identitiesEntries: [(Principal, Identity)] = [];
    private var identities = HashMap.HashMap<Principal, Identity>(5, Principal.equal, Principal.hash);

    // Stable storage for verifiable credentials
    private stable var credentialsEntries: [(Text, VerifiableCredential)] = [];
    private var credentials = HashMap.HashMap<Text, VerifiableCredential>(5, Text.equal, Text.hash);

    // Stable storage for authentication requests
    private stable var adminAuthRequestsEntries: [(Text, Nat)] = [];
    private var adminAuthRequests = HashMap.HashMap<Text, Nat>(5, Text.equal, Text.hash);

    // Stable storage for user identity confirmations
    private stable var userIdentityConfirmationsEntries: [(Text, (Nat, Principal))] = [];
    private var userIdentityConfirmations = HashMap.HashMap<Text, (Nat, Principal)>(5, Text.equal, Text.hash);

    // Counter for generating unique credential IDs
    private stable var nextCredentialId: Nat = 0;

    // Helper function to get current time in nanoseconds
    private func getCurrentTime(): Nat {
        Int.abs(Time.now())
    };

    // Initiate an authentication request for a user (called by admin)
    public shared ({ caller }) func initiateAuth(
        sessionId: Text,
        expirationNanoseconds: ?Nat
    ): async Response {
        if (caller != admin) {
            return #Unauthorized;
        };

        let actualExpirationNanoseconds: Nat = switch (expirationNanoseconds) {
            case null { DEFAULT_EXPIRATION_NANOSECONDS };
            case (?expiration) { expiration };
        };

        let now = getCurrentTime();
        let expiration = now + actualExpirationNanoseconds;

        adminAuthRequests.put(sessionId, expiration);

        // Cleanup if session has already been confirmed
        switch (userIdentityConfirmations.get(sessionId)) {
            case null {};
            case _ { userIdentityConfirmations.delete(sessionId) };
        };

        return #Ok;
    };

    // Verify a user's identity (called by admin)
    public shared ({ caller }) func verifyIdentity(sessionId: Text): async (Response, ?Principal) {
        if (caller != admin) {
            return (#Unauthorized, null);
        };

        switch (userIdentityConfirmations.get(sessionId)) {
            case null {
                return (#NotConfirmed, null);
            };
            case (?(_, userPrincipal)) {
                userIdentityConfirmations.delete(sessionId);
                return (#Ok, ?userPrincipal);
            };
        };
    };

    // Confirm identity (called by user)
    public shared ({ caller }) func confirmIdentity(sessionId: Text): async Response {
        if (Principal.isAnonymous(caller)) {
            return #Unauthorized;
        };

        let now = getCurrentTime();

        switch (adminAuthRequests.get(sessionId)) {
            case null {
                return #InvalidSession;
            };
            case (?expiration) {
                if (expiration < now) {
                    adminAuthRequests.delete(sessionId);
                    return #Expired;
                };
                adminAuthRequests.delete(sessionId);
            };
        };

        userIdentityConfirmations.put(sessionId, (now, caller));
        return #Ok;
    };

    // Register a new self-sovereign identity
    public shared ({ caller }) func registerIdentity(): async Result.Result<Identity, Errors> {
        if (identities.get(caller) != null) {
            return #err(#IdentityAlreadyExists);
        };

        let now = getCurrentTime();
        let newIdentity: Identity = {
            id = caller;
            owner = caller;
            createdAt = now;
            updatedAt = now;
            verified = false;
        };
        identities.put(caller, newIdentity);
        return #ok(newIdentity);
    };

    // Add a verifiable credential (e.g., passport, property deed)
    public shared ({ caller }) func addVerifiableCredential(
        credentialType: Text,
        issuer: Text,
        issuedAt: Nat,
        expirationDate: ?Nat,
        credentialHash: Text // IPFS CID or document hash
    ): async Result.Result<VerifiableCredential, Errors> {
        let identity = switch (identities.get(caller)) {
            case null { return #err(#IdentityNotFound) };
            case (?id) { id };
        };

        // Check for duplicate credential
        for ((_, cred) in credentials.entries()) {
            if (cred.ownerId == caller and cred.credentialType == credentialType and cred.credentialHash == credentialHash) {
                return #err(#CredentialAlreadyExists);
            };
        };

        let credentialId = Nat.toText(nextCredentialId);
        nextCredentialId += 1;

        let newCredential: VerifiableCredential = {
            id = credentialId;
            ownerId = caller;
            credentialType = credentialType;
            issuer = issuer;
            issuedAt = issuedAt;
            expirationDate = expirationDate;
            credentialHash = credentialHash;
            status = #Valid;
        };
        credentials.put(credentialId, newCredential);

        // Update identity to mark as verified if this is a critical credential (e.g., passport)
        if (credentialType == "Passport" or credentialType == "GovernmentID") {
            let updatedIdentity: Identity = {
                id = identity.id;
                owner = identity.owner;
                createdAt = identity.createdAt;
                updatedAt = getCurrentTime();
                verified = true;
            };
            identities.put(caller, updatedIdentity);
        };

        return #ok(newCredential);
    };

    // Update credential status (e.g., revoke, suspend)
    public shared ({ caller }) func updateCredentialStatus(
        credentialId: Text,
        newStatus: Types.CredentialStatus
    ): async Result.Result<Bool, Errors> {
        if (caller != admin) {
            return #err(#Unauthorized);
        };

        let credential = switch (credentials.get(credentialId)) {
            case null { return #err(#CredentialNotFound) };
            case (?cred) { cred };
        };

        let updatedCredential: VerifiableCredential = {
            id = credential.id;
            ownerId = credential.ownerId;
            credentialType = credential.credentialType;
            issuer = credential.issuer;
            issuedAt = credential.issuedAt;
            expirationDate = credential.expirationDate;
            credentialHash = credential.credentialHash;
            status = newStatus;
        };
        credentials.put(credentialId, updatedCredential);
        return #ok(true);
    };

    // Check if a user is verified (for whitelist integration)
    public shared query func checkVerified(user: Principal): async Bool {
        switch (identities.get(user)) {
            case (?identity) { identity.verified };
            case null { false };
        }
    };

    // Query identity by principal
    public query func getIdentity(id: Principal): async ?Identity {
        identities.get(id);
    };

    // Query credentials by owner
    public query func getVerifiableCredentials(ownerId: Principal): async [VerifiableCredential] {
        let buffer = Buffer.Buffer<VerifiableCredential>(0);
        for ((_, cred) in credentials.entries()) {
            if (cred.ownerId == ownerId) {
                buffer.add(cred);
            };
        };
        buffer.toArray()
    };

    // Query a specific credential
    public query func getVerifiableCredential(credentialId: Text): async ?VerifiableCredential {
        credentials.get(credentialId);
    };

    // Documentation
    public query func documentation(): async Text {
        Text.join(
            "\n",
            [
                "Identity Verifier Canister",
                "",
                "This canister enables on-chain identity verification with document storage for hybrid dApps.",
                "It supports self-sovereign identities and verifiable credentials linked to off-chain documents.",
                "",
                "Key Features:",
                "- Register self-sovereign identities with `registerIdentity`.",
                "- Add verifiable credentials (e.g., passports, property deeds) with `addVerifiableCredential`.",
                "- Admin-initiated authentication sessions via `initiateAuth`, `verifyIdentity`, and `confirmIdentity`.",
                "- Integration with property tokenization via `checkVerified` for whitelists.",
                "- Stores document references (e.g., IPFS CIDs) to maintain privacy.",
                "",
                "Flow:",
                "1. User registers identity with `registerIdentity`.",
                "2. User submits credentials (e.g., passport) with `addVerifiableCredential`, referencing off-chain documents.",
                "3. Admin initiates auth session with `initiateAuth`.",
                "4. User confirms identity with `confirmIdentity`.",
                "5. Admin verifies with `verifyIdentity`.",
                "6. Property tokenization canisters check `checkVerified` for whitelist eligibility.",
                "",
                "Security Notes:",
                "- Only the admin can initiate auth sessions or update credential status.",
                "- Sensitive data is stored off-chain (e.g., IPFS) with hashes stored on-chain.",
                "- Deploy with: `dfx deploy --argument '(principal \"<admin-principal>\")'`",
                "",
                "Error Responses:",
                "- #Unauthorized: Caller lacks permission.",
                "- #Expired: Session has expired.",
                "- #NotConfirmed: User has not confirmed identity.",
                "- #InvalidSession: Invalid session ID.",
                "- #IdentityAlreadyExists: Identity already registered.",
                "- #IdentityNotFound: Identity does not exist.",
                "- #CredentialAlreadyExists: Credential already exists.",
                "- #CredentialNotFound: Credential not found."
            ].vals()
        )
    };

    // System functions for upgrades
    system func preupgrade() {
        identitiesEntries := Iter.toArray(identities.entries());
        credentialsEntries := Iter.toArray(credentials.entries());
        adminAuthRequestsEntries := Iter.toArray(adminAuthRequests.entries());
        userIdentityConfirmationsEntries := Iter.toArray(userIdentityConfirmations.entries());
    };

    system func postupgrade() {
        identities := HashMap.fromIter<Principal, Identity>(identitiesEntries.vals(), 5, Principal.equal, Principal.hash);
        credentials := HashMap.fromIter<Text, VerifiableCredential>(credentialsEntries.vals(), 5, Text.equal, Text.hash);
        adminAuthRequests := HashMap.fromIter<Text, Nat>(adminAuthRequestsEntries.vals(), 5, Text.equal, Text.hash);
        userIdentityConfirmations := HashMap.fromIter<Text, (Nat, Principal)>(userIdentityConfirmationsEntries.vals(), 5, Text.equal, Text.hash);
        identitiesEntries := [];
        credentialsEntries := [];
        adminAuthRequestsEntries := [];
        userIdentityConfirmationsEntries := [];
        CertifiedData.set(Blob.fromArray([Nat8.fromNat(nextCredentialId)]));
    };

    /// Returns a certified hash of the credential registry (stub).
    public query func get_certified_data() : async Blob {
        CertifiedData.get()
    };
};