/**
 * Module     : types.mo
 * Copyright  : 2025 YourTeam
 * License    : Apache 2.0 with LLVM Exception
 * Description: Types for property tokenization smart contract
 */

import Time "mo:base/Time";
import TrieSet "mo:base/TrieSet";

module {
    public type PropertyMetadata = {
        propertyAddress: Text;
        propertyValue: Nat; // in cents
        legalDocuments: Text; // IPFS link or hash to legal docs
        description: Text;
        attributes: [(Text, Text)]; // e.g., [("squareFeet", "2000"), ("bedrooms", "4")]
    };

    public type TokenMetadata = {
        propertyId: ?Nat; // Links to main property token
        sharePercentage: Nat; // Ownership percentage in basis points (e.g., 100 = 1%)
        propertyMetadata: ?PropertyMetadata;
    };

    public type TokenInfo = {
        index: Nat;
        var owner: Principal;
        var metadata: ?TokenMetadata;
        var operator: ?Principal;
        timestamp: Time.Time;
    };

    public type TokenInfoExt = {
        index: Nat;
        owner: Principal;
        metadata: ?TokenMetadata;
        operator: ?Principal;
        timestamp: Time.Time;
    };

    public type UserInfo = {
        var operators: TrieSet.Set<Principal>;
        var allowedBy: TrieSet.Set<Principal>;
        var allowedTokens: TrieSet.Set<Nat>;
        var tokens: TrieSet.Set<Nat>;
    };

    public type UserInfoExt = {
        operators: [Principal];
        allowedBy: [Principal];
        allowedTokens: [Nat];
        tokens: [Nat];
    };

    public type SaleInfo = {
        propertyId: Nat;
        startTime: Int;
        endTime: Int;
        minPerUser: Nat;
        maxPerUser: Nat;
        totalShares: Nat;
        var sharesLeft: Nat;
        var fundRaised: Nat;
        pricePerShare: Nat;
        paymentToken: Principal;
        whitelist: ?Principal;
        var fundsClaimed: Bool;
    };

    public type SaleInfoExt = {
        propertyId: Nat;
        startTime: Int;
        endTime: Int;
        minPerUser: Nat;
        maxPerUser: Nat;
        totalShares: Nat;
        sharesLeft: Nat;
        fundRaised: Nat;
        pricePerShare: Nat;
        paymentToken: Principal;
        whitelist: ?Principal;
        fundsClaimed: Bool;
    };

    public type Operation = {
        #mint: ?TokenMetadata;
        #burn;
        #transfer;
        #transferFrom;
        #approve;
        #approveAll;
        #revokeAll;
        #setMetadata;
    };

    public type Record = {
        #user: Principal;
        #metadata: ?TokenMetadata;
    };

    public type TxRecord = {
        caller: Principal;
        op: Operation;
        index: Nat;
        tokenIndex: ?Nat;
        from: Record;
        to: Record;
        timestamp: Time.Time;
    };
};