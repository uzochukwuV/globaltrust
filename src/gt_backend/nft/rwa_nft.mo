/**
 * RWA NFT Canister implementing ICRC-7/37 (NFT) subset with custom RWA constraints.
 * Copyright 2025
 * License: Apache 2.0 with LLVM Exception
 */

import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import CertifiedData "mo:base/CertifiedData";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";
import SHA256 "mo:sha2/SHA256";

actor class RwaNft(admin: Principal, verificationOrchestrator: Principal) = this {

    // --- Types ---

    public type TokenId = Nat;
    public type Account = Principal;

    public type RwaNftMetadata = {
        ipfs_cid: Text;
        rwa_type: Text;
        submission_id: Text;
        attestation_ids: [Text];
        verification_hash: Text;
        lien_active: Bool;
        collateralized: Bool;
        frozen: Bool;
    };

    public type TokenData = {
        id: TokenId;
        var owner: Account;
        var metadata: RwaNftMetadata;
        mint_time: Time.Time;
    };

    public type MintArgs = {
        to: Account;
        metadata: RwaNftMetadata;
    };

    public type TransferArgs = {
        from: Account;
        to: Account;
        tokenId: TokenId;
    };

    public type Error = {
        #Unauthorized;
        #TokenNotFound;
        #Frozen;
        #Collateralized;
        #AlreadyFrozen;
        #NotFrozen;
        #InvalidOperation;
        #AlreadyCollateralized;
        #NotCollateralized;
        #AlreadyLien;
        #NotLien;
        #CannotTransferToSelf;
        #Other : Text;
    };

    public type EventKind = {
        #Mint;
        #Transfer;
        #Freeze;
        #Unfreeze;
        #LienOn;
        #LienOff;
        #Collateralized;
        #ReleasedCollateral;
    };

    public type Event = {
        event: EventKind;
        tokenId: TokenId;
        from: ?Account;
        to: ?Account;
        timestamp: Time.Time;
        details: ?Text;
    };

    public type CertifiedMetadata = {
        metadata: RwaNftMetadata;
        certificate: Blob;
    };

    // --- Storage ---

    private stable var stable_tokenId: Nat = 0;
    private stable var stable_tokens : [(TokenId, TokenData)] = [];
    private stable var stable_events : [Event] = [];

    private var tokens = HashMap.HashMap<TokenId, TokenData>(1, Nat.equal, Hash.hash);
    private var events = Buffer.Buffer<Event>(100);

    // CertifiedData: root hash of (tokenId -> metadata hash)
    private stable var stable_certified_hash_map : [(TokenId, Blob)] = [];
    private var certified_hash_map = HashMap.HashMap<TokenId, Blob>(1, Nat.equal, Hash.hash);

    // --- Policy ---

    private func isAdminOrVO(caller: Principal) : Bool {
        caller == admin or caller == verificationOrchestrator
    };

    // --- Internal helpers ---

    private func nextTokenId() : TokenId {
        let id = stable_tokenId;
        stable_tokenId += 1;
        id
    };

    private func storeToken(token: TokenData) {
        tokens.put(token.id, token);
        // Update certified_data hash map
        let hash = hashMetadata(token.metadata);
        certified_hash_map.put(token.id, hash);
        updateCertifiedRoot();
    };

    private func hashMetadata(meta: RwaNftMetadata) : Blob {
        // Concatenate all fields and hash
        let txt = meta.ipfs_cid # "|" # meta.rwa_type # "|" # meta.submission_id # "|" #
            Text.join(",", meta.attestation_ids) # "|" # meta.verification_hash # "|" #
            (if meta.lien_active then "1" else "0") # (if meta.collateralized then "1" else "0") # (if meta.frozen then "1" else "0");
        Blob.fromArray(SHA256.sha256(Text.encodeUtf8(txt)))
    };

    private func updateCertifiedRoot() {
        // For demo: compute root as sha256 of sorted concatenation of tokenId+metadata_hash
        let arr = Iter.toArray(certified_hash_map.entries());
        let sorted = Array.sort(arr, func a b = Nat.compare(a.0, b.0));
        let combined = Buffer.Buffer<Nat8>(0);
        for ((tokenId, hash) in sorted.vals()) {
            let idBytes = Nat.toText(tokenId);
            for (b in Text.encodeUtf8(idBytes)) { combined.add(b); };
            for (b in Blob.toArray(hash)) { combined.add(b); };
        };
        let root = SHA256.sha256(Buffer.toArray(combined));
        CertifiedData.set(Blob.fromArray(root));
    };

    private func getTokenOrErr(tokenId: TokenId) : Result.Result<TokenData, Error> {
        switch tokens.get(tokenId) {
            case (?t) { #ok(t) };
            case null { #err(#TokenNotFound) }
        }
    };

    private func logEvent(event: Event) {
        events.add(event);
        stable_events := Array.append(stable_events, [event]);
    };

    // --- Public API ---

    // Minting
    public shared(msg) func mintRwaNft(args: MintArgs): async Result.Result<TokenId, Error> {
        if (not isAdminOrVO(msg.caller)) return #err(#Unauthorized);
        let tokenId = nextTokenId();
        let token : TokenData = {
            id = tokenId;
            var owner = args.to;
            var metadata = args.metadata;
            mint_time = Time.now();
        };
        storeToken(token);
        logEvent({
            event = #Mint;
            tokenId = tokenId;
            from = null;
            to = ?args.to;
            timestamp = Time.now();
            details = null;
        });
        #ok(tokenId)
    };

    // Lien management
    public shared(msg) func setLien(tokenId: TokenId, active: Bool) : async Result.Result<(), Error> {
        let caller = msg.caller;
        let res = getTokenOrErr(tokenId);
        switch res {
            case (#err(e)) return #err(e);
            case (#ok(token)) {
                if (not isAdminOrVO(caller)) return #err(#Unauthorized);
                if (token.metadata.lien_active == active) return #err(if active then #AlreadyLien else #NotLien);
                token.metadata.lien_active := active;
                storeToken(token);
                logEvent({
                    event = if active then #LienOn else #LienOff;
                    tokenId = tokenId;
                    from = null;
                    to = null;
                    timestamp = Time.now();
                    details = null;
                });
                #ok(())
            }
        }
    };

    // Collateral management
    public shared(msg) func setCollateralized(tokenId: TokenId, active: Bool) : async Result.Result<(), Error> {
        let caller = msg.caller;
        let res = getTokenOrErr(tokenId);
        switch res {
            case (#err(e)) return #err(e);
            case (#ok(token)) {
                if (not isAdminOrVO(caller)) return #err(#Unauthorized);
                if (token.metadata.collateralized == active) return #err(if active then #AlreadyCollateralized else #NotCollateralized);
                token.metadata.collateralized := active;
                storeToken(token);
                logEvent({
                    event = if active then #Collateralized else #ReleasedCollateral;
                    tokenId = tokenId;
                    from = null;
                    to = null;
                    timestamp = Time.now();
                    details = null;
                });
                #ok(())
            }
        }
    };

    // Freeze/unfreeze
    public shared(msg) func freeze(tokenId: TokenId) : async Result.Result<(), Error> {
        let caller = msg.caller;
        let res = getTokenOrErr(tokenId);
        switch res {
            case (#err(e)) return #err(e);
            case (#ok(token)) {
                if (not isAdminOrVO(caller)) return #err(#Unauthorized);
                if (token.metadata.frozen) return #err(#AlreadyFrozen);
                token.metadata.frozen := true;
                storeToken(token);
                logEvent({
                    event = #Freeze;
                    tokenId = tokenId;
                    from = null;
                    to = null;
                    timestamp = Time.now();
                    details = null;
                });
                #ok(())
            }
        }
    };

    public shared(msg) func unfreeze(tokenId: TokenId) : async Result.Result<(), Error> {
        let caller = msg.caller;
        let res = getTokenOrErr(tokenId);
        switch res {
            case (#err(e)) return #err(e);
            case (#ok(token)) {
                if (not isAdminOrVO(caller)) return #err(#Unauthorized);
                if (not token.metadata.frozen) return #err(#NotFrozen);
                token.metadata.frozen := false;
                storeToken(token);
                logEvent({
                    event = #Unfreeze;
                    tokenId = tokenId;
                    from = null;
                    to = null;
                    timestamp = Time.now();
                    details = null;
                });
                #ok(())
            }
        }
    };

    // Safe transfer, enforcing all constraints
    public shared(msg) func safeTransfer(args: TransferArgs) : async Result.Result<(), Error> {
        let caller = msg.caller;
        let res = getTokenOrErr(args.tokenId);
        switch res {
            case (#err(e)) return #err(e);
            case (#ok(token)) {
                if (token.owner != args.from) return #err(#Unauthorized);
                if (caller != token.owner and not isAdminOrVO(caller)) return #err(#Unauthorized);
                if (args.from == args.to) return #err(#CannotTransferToSelf);
                if (token.metadata.frozen) return #err(#Frozen);
                if (token.metadata.collateralized) return #err(#Collateralized);
                // Transfer
                let oldOwner = token.owner;
                token.owner := args.to;
                storeToken(token);
                logEvent({
                    event = #Transfer;
                    tokenId = args.tokenId;
                    from = ?oldOwner;
                    to = ?args.to;
                    timestamp = Time.now();
                    details = null;
                });
                #ok(())
            }
        }
    };

    // --- Queries ---

    public query func ownerOf(tokenId: TokenId) : async Result.Result<Account, Error> {
        switch tokens.get(tokenId) {
            case (?token) #ok(token.owner);
            case null #err(#TokenNotFound)
        }
    };

    public query func tokenMetadata(tokenId: TokenId) : async Result.Result<RwaNftMetadata, Error> {
        switch tokens.get(tokenId) {
            case (?token) #ok(token.metadata);
            case null #err(#TokenNotFound)
        }
    };

    public query func totalSupply() : async Nat {
        tokens.size()
    };

    // --- Certified Data ---

    public query func getCertifiedMetadata(tokenId: TokenId) : async ?CertifiedMetadata {
        switch tokens.get(tokenId) {
            case null null;
            case (?token) {
                let hash = certified_hash_map.get(tokenId);
                let cert = CertifiedData.getCertificate();
                ?{
                    metadata = token.metadata;
                    certificate = cert;
                }
            }
        }
    };

    // --- Events ---

    public query func getEvents() : async [Event] {
        events.toArray()
    };

    // --- Upgrade (Stable) ---

    system func preupgrade() {
        stable_tokenId := stable_tokenId;
        stable_tokens := Iter.toArray(tokens.entries());
        stable_events := events.toArray();
        stable_certified_hash_map := Iter.toArray(certified_hash_map.entries());
    };

    system func postupgrade() {
        tokens := HashMap.fromIter<TokenId, TokenData>(stable_tokens.vals(), 1, Nat.equal, Hash.hash);
        events := Buffer.Buffer<Event>(stable_events.size());
        for (e in stable_events.vals()) { events.add(e); };
        certified_hash_map := HashMap.fromIter<TokenId, Blob>(stable_certified_hash_map.vals(), 1, Nat.equal, Hash.hash);
        updateCertifiedRoot();
    };
};