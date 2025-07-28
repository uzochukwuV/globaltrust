/**
 * Module     : main.mo
 * Copyright  : 2025 YourTeam
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : YourTeam <your.email@example.com>
 * Stability  : Experimental
 * Description: Smart contract for tokenizing real-world assets (properties) on ICP
 */

import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieSet "mo:base/TrieSet";
import Prelude "mo:base/Prelude";

import Types "./types";

shared(msg) actor class PropertyToken(
) = this {

    type PropertyMetadata = Types.PropertyMetadata;
    type TokenMetadata = Types.TokenMetadata;
    type TokenInfo = Types.TokenInfo;
    type TokenInfoExt = Types.TokenInfoExt;
    type UserInfo = Types.UserInfo;
    type UserInfoExt = Types.UserInfoExt;
    type TxRecord = Types.TxRecord;
    type Operation = Types.Operation;
    type Record = Types.Record;
    type SaleInfo = Types.SaleInfo;
    type SaleInfoExt = Types.SaleInfoExt;

    public type Errors = {
        #Unauthorized;
        #TokenNotExist;
        #InvalidOperator;
        #SaleNotActive;
        #InsufficientFunds;
        #InvalidAmount;
        #NotWhitelisted;
    };

    public type TxReceipt = {
        #Ok: Nat;
        #Err: Errors;
    };

    public type MintResult = {
        #Ok: (Nat, Nat);
        #Err: Errors;
    };

    public type Result<Ok, Err> = {#ok: Ok; #err: Err};

    // DIP20 token actor for payments
    type DIP20Errors = {
        #InsufficientBalance;
        #InsufficientAllowance;
        #LedgerTrap;
        #AmountTooSmall;
        #BlockUsed;
        #ErrorOperationStyle;
        #ErrorTo;
        #Other;
    };
    type DIP20Metadata = {
        logo: Text;
        name: Text;
        symbol: Text;
        decimals: Nat8;
        totalSupply: Nat;
        owner: Principal;
        fee: Nat;
    };
    public type TxReceiptToken = {
        #Ok: Nat;
        #Err: DIP20Errors;
    };
    type TokenActor = actor {
        transferFrom: shared (from: Principal, to: Principal, value: Nat) -> async TxReceiptToken;
        getMetadata: () -> async DIP20Metadata;
    };

    private stable var logo_: Text = "";
    private stable var name_: Text = "";
    private stable var symbol_: Text = "";
    private stable var desc_: Text = "";
    private stable var owner_: Principal = msg.caller;
    private stable var paymentToken_: Principal = Principal.fromText("3emtq-fq33w-tc3s5-qqcdi-rx6hb-aend7-s4wfw-57o35-t275p-blwia-tae");
    private stable var totalSupply_: Nat = 0;
    private stable var blackhole: Principal = Principal.fromText("aaaaa-aa");

    private stable var tokensEntries: [(Nat, TokenInfo)] = [];
    private stable var usersEntries: [(Principal, UserInfo)] = [];
    private stable var salesEntries: [(Nat, SaleInfo)] = [];
    private var tokens = HashMap.HashMap<Nat, TokenInfo>(1, Nat.equal, Hash.hash);
    private var users = HashMap.HashMap<Principal, UserInfo>(1, Principal.equal, Principal.hash);
    private var sales = HashMap.HashMap<Nat, SaleInfo>(1, Nat.equal, Hash.hash);
    private stable var txs: [TxRecord] = [];
    private stable var txIndex: Nat = 0;

    private func addTxRecord(
        caller: Principal, op: Operation, tokenIndex: ?Nat,
        from: Record, to: Record, timestamp: Time.Time
    ): Nat {
        let record: TxRecord = {
            caller = caller;
            op = op;
            index = txIndex;
            tokenIndex = tokenIndex;
            from = from;
            to = to;
            timestamp = timestamp;
        };
        txs := Array.append(txs, [record]);
        txIndex += 1;
        return txIndex - 1;
    };

    private func _unwrap<T>(x: ?T): T {
        switch x {
            case null { Prelude.unreachable() };
            case (?x_) { x_ };
        }
    };

    private func _exists(tokenId: Nat): Bool {
        switch (tokens.get(tokenId)) {
            case (?info) { return true; };
            case _ { return false; };
        }
    };

    private func _ownerOf(tokenId: Nat): ?Principal {
        switch (tokens.get(tokenId)) {
            case (?info) { return ?info.owner; };
            case (_) { return null; };
        }
    };

    private func _isOwner(who: Principal, tokenId: Nat): Bool {
        switch (tokens.get(tokenId)) {
            case (?info) { return info.owner == who; };
            case _ { return false; };
        }
    };

    private func _isApproved(who: Principal, tokenId: Nat): Bool {
        switch (tokens.get(tokenId)) {
            case (?info) { return info.operator == ?who; };
            case _ { return false; };
        }
    };

    private func _balanceOf(who: Principal): Nat {
        switch (users.get(who)) {
            case (?user) { return TrieSet.size(user.tokens); };
            case (_) { return 0; };
        }
    };

    private func _newUser(): UserInfo {
        {
            var operators = TrieSet.empty<Principal>();
            var allowedBy = TrieSet.empty<Principal>();
            var allowedTokens = TrieSet.empty<Nat>();
            var tokens = TrieSet.empty<Nat>();
        }
    };

    private func _tokenInfotoExt(info: TokenInfo): TokenInfoExt {
        return {
            index = info.index;
            owner = info.owner;
            metadata = info.metadata;
            timestamp = info.timestamp;
            operator = info.operator;
        };
    };

    private func _userInfotoExt(info: UserInfo): UserInfoExt {
        return {
            operators = TrieSet.toArray(info.operators);
            allowedBy = TrieSet.toArray(info.allowedBy);
            allowedTokens = TrieSet.toArray(info.allowedTokens);
            tokens = TrieSet.toArray(info.tokens);
        };
    };

    private func _isApprovedOrOwner(spender: Principal, tokenId: Nat): Bool {
        switch (_ownerOf(tokenId)) {
            case (?owner) {
                return spender == owner or _isApproved(spender, tokenId) or _isApprovedForAll(owner, spender);
            };
            case _ { return false; };
        };
    };

    private func _getApproved(tokenId: Nat): ?Principal {
        switch (tokens.get(tokenId)) {
            case (?info) { return info.operator; };
            case (_) { return null; };
        }
    };

    private func _isApprovedForAll(owner: Principal, operator: Principal): Bool {
        switch (users.get(owner)) {
            case (?user) {
                return TrieSet.mem(user.operators, operator, Principal.hash(operator), Principal.equal);
            };
            case _ { return false; };
        };
    };

    private func _addTokenTo(to: Principal, tokenId: Nat) {
        switch(users.get(to)) {
            case (?user) {
                user.tokens := TrieSet.put(user.tokens, tokenId, Hash.hash(tokenId), Nat.equal);
                users.put(to, user);
            };
            case _ {
                let user = _newUser();
                user.tokens := TrieSet.put(user.tokens, tokenId, Hash.hash(tokenId), Nat.equal);
                users.put(to, user);
            };
        }
    };

    private func _removeTokenFrom(owner: Principal, tokenId: Nat) {
        assert(_exists(tokenId) and _isOwner(owner, tokenId));
        switch(users.get(owner)) {
            case (?user) {
                user.tokens := TrieSet.delete(user.tokens, tokenId, Hash.hash(tokenId), Nat.equal);
                users.put(owner, user);
            };
            case _ {
                assert(false);
            };
        }
    };

    private func _clearApproval(tokenId: Nat, owner: Principal) {
            assert(_exists(tokenId) and _isOwner(owner, tokenId));
            switch (tokens.get(tokenId)) {
                case (?info) {
                    if (info.operator != null) {
                        let op = _unwrap(info.operator);
                        let opInfo = _unwrap(users.get(op));
                        opInfo.allowedTokens := TrieSet.delete(opInfo.allowedTokens, tokenId, Hash.hash(tokenId), Nat.equal);
                        users.put(op, opInfo);
                        info.operator := null;
                        tokens.put(tokenId, info);
                    }
                };
                case _ {
                    assert(false);
                };
            }
        };
    private func _transfer(to: Principal, tokenId: Nat) {
        assert(_exists(tokenId));
        switch(tokens.get(tokenId)) {
            case (?info) {
                _removeTokenFrom(info.owner, tokenId);
                _addTokenTo(to, tokenId);
                info.owner := to;
                tokens.put(tokenId, info);
            };
            case (_) {
                assert(false);
            };
        }
    };

    private func _burn(owner: Principal, tokenId: Nat) {
        _clearApproval(tokenId, owner);
        _transfer(blackhole, tokenId);
    };

    // Mint a property as an NFT with fractional tokens
    public shared(msg) func mintProperty(
        propertyMetadata: Nat,
        fractionalShares: Nat,
        metadata: ?PropertyMetadata
    ): async MintResult {
        if (msg.caller != owner_) {
            return #Err(#Unauthorized);
        };
        let propertyId = totalSupply_;
        let token: TokenInfo = {
            index = propertyId;
            var owner = owner_;
            var metadata = ?{
                propertyId = ?propertyId;
                sharePercentage = 0; // Main property token
                propertyMetadata = metadata;
            };
            var operator = null;
            timestamp = Time.now();
        };
        tokens.put(propertyId, token);
        _addTokenTo(owner_, propertyId);
        totalSupply_ += 1;
        let propertyTxId = addTxRecord(
            msg.caller,
            #mint(token.metadata),
            ?propertyId,
            #user(blackhole),
            #user(owner_),
            Time.now()
        );

        // Mint fractional tokens
        let startShareIndex = totalSupply_;
        for (i in Iter.range(1, fractionalShares)) {
            let shareToken: TokenInfo = {
                index = totalSupply_;
                var owner = owner_;
                var metadata = ?{
                    propertyId = ?propertyId;
                    sharePercentage = 10000 / fractionalShares; // 100% split equally in basis points
                    propertyMetadata = null;
                };
                var operator = null;
                timestamp = Time.now();
            };
            tokens.put(totalSupply_, shareToken);
            _addTokenTo(owner_, totalSupply_);
            totalSupply_ += totalSupply_ + 1;
            ignore addTxRecord(
                msg.caller,
                #mint(shareToken.metadata),
                ?shareToken.index,
                #user(blackhole),
                #user(owner_),
                Time.now()
            );
        };
        return #Ok((propertyId, propertyTxId));
    };

    // Initiate a sale for fractional shares
    public shared(msg) func startSale(
        propertyId: Nat,
        shares: Nat,
        pricePerShare: Nat,
        startTime: Int,
        endTime: Int,
        minPerUser: Nat,
        maxPerUser: Nat,
        whitelist: ?Principal
    ): async Result<Nat, Errors> {
        if (msg.caller != owner_) {
            return #err(#Unauthorized);
        };
        if (not _exists(propertyId)) {
            return #err(#TokenNotExist);
        };
        let saleInfo: SaleInfo = {
            propertyId = propertyId;
            startTime = startTime;
            endTime = endTime;
            minPerUser = minPerUser;
            maxPerUser = maxPerUser;
            totalShares = shares;
            var sharesLeft = shares;
            var fundRaised = 0;
            pricePerShare = pricePerShare;
            paymentToken = paymentToken_;
            whitelist = whitelist;
            var fundsClaimed = false;
        };
        sales.put(propertyId, saleInfo);
        return #ok(propertyId);
    };

    // Buy fractional shares
    public shared(msg) func buyShares(propertyId: Nat, amount: Nat): async Result<Nat, Errors> {
        let sale = switch (sales.get(propertyId)) {
            case (?s) { s };
            case (_) { return #err(#SaleNotActive); };
        };
        if (Time.now() < sale.startTime or Time.now() > sale.endTime) {
            return #err(#SaleNotActive);
        };
        let userBalance = _balanceOf(msg.caller);
        if (amount < sale.minPerUser or userBalance + amount > sale.maxPerUser) {
            return #err(#InvalidAmount);
        };
        if (amount > sale.sharesLeft) {
            return #err(#InvalidAmount);
        };
        switch (sale.whitelist) {
            case (?whitelist) {
                let whitelistActor = actor(Principal.toText(whitelist)) : actor { check: shared(Principal) -> async Bool };
                if ((await whitelistActor.check(msg.caller) )== false) {
                    return #err(#NotWhitelisted);
                };
            };
            case (_) {
                return #err(#NotWhitelisted);
            };
        };
        let tokenActor: TokenActor = actor(Principal.toText(sale.paymentToken));
        let totalCost = amount * sale.pricePerShare;
        switch (await tokenActor.transferFrom(msg.caller, Principal.fromActor(this), totalCost)) {
            case (#Ok(_)) {
                sale.sharesLeft -= amount;
                sale.fundRaised += totalCost;
                sales.put(propertyId, sale);
                // Transfer shares to buyer
                var transferred = 0;
                for (tokenId in Iter.range(totalSupply_ - sale.totalShares, totalSupply_ - 1)) {
                    if (transferred <= amount) {
                        switch(tokens.get(tokenId)) {
                        case null { };
                        case (?token) {
                            if (token.owner == owner_ and token.metadata != null) {
                                let metadata = _unwrap(token.metadata);
                                if (metadata.propertyId == ?propertyId) {
                                    _transfer(msg.caller, tokenId);
                                    ignore addTxRecord(
                                        msg.caller,
                                        #transfer,
                                        ?tokenId,
                                        #user(owner_),
                                        #user(msg.caller),
                                        Time.now()
                                    );
                                    transferred += 1;
                                };
                            };
                        };
                    };
                    }
                    
                };
                return #ok(transferred);
            };
            case (#Err(_)) {
                return #err(#InsufficientFunds);
            };
        };
    };

    // Claim funds from sale
    public shared(msg) func claimSaleFunds(propertyId: Nat): async Result<Bool, Errors> {
        if (msg.caller != owner_) {
            return #err(#Unauthorized);
        };
        let sale = switch (sales.get(propertyId)) {
            case (?s) { s };
            case (_) { return #err(#SaleNotActive); };
        };
        if (not sale.fundsClaimed) {
            sale.fundsClaimed := true;
            sales.put(propertyId, sale);
            let tokenActor: TokenActor = actor(Principal.toText(sale.paymentToken));
            let metadata = await tokenActor.getMetadata();
            switch (await tokenActor.transferFrom(Principal.fromActor(this),owner_, sale.fundRaised - metadata.fee)) {
                case (#Ok(_)) {
                    return #ok(true);
                };
                case (#Err(_)) {
                    sale.fundsClaimed := false;
                    sales.put(propertyId, sale);
                    return #err(#InsufficientFunds);
                };
            };
        };
        return #ok(true);
    };

    // Transfer tokens
    public shared(msg) func transfer(to: Principal, tokenId: Nat): async TxReceipt {
        if (not _exists(tokenId)) {
            return #Err(#TokenNotExist);
        };
        if ( not _isOwner(msg.caller, tokenId)) {
            return #Err(#Unauthorized);
        };
        _clearApproval(tokenId, msg.caller);
        _transfer(to, tokenId);
        let txid = addTxRecord(msg.caller, #transfer, ?tokenId, #user(msg.caller), #user(to), Time.now());
        return #Ok(txid);
    };

    // Query functions
    public query func getSaleInfo(propertyId: Nat): async ?SaleInfoExt {
        switch (sales.get(propertyId)) {
            case (?sale) {
                ?{
                    propertyId = sale.propertyId;
                    startTime = sale.startTime;
                    endTime = sale.endTime;
                    minPerUser = sale.minPerUser;
                    maxPerUser = sale.maxPerUser;
                    totalShares = sale.totalShares;
                    sharesLeft = sale.sharesLeft;
                    fundRaised = sale.fundRaised;
                    pricePerShare = sale.pricePerShare;
                    paymentToken = sale.paymentToken;
                    whitelist = sale.whitelist;
                    fundsClaimed = sale.fundsClaimed;
                }
            };
            case (_) { null };
        }
    };

    public query func getTokenInfo(tokenId: Nat): async Result<TokenInfoExt, Errors> {
        switch (tokens.get(tokenId)) {
            case (?tokeninfo) {
                return #ok(_tokenInfotoExt(tokeninfo));
            };
            case (_) {
                return #err(#TokenNotExist);
            };
        }
    };

    public query func balanceOf(who: Principal): async Nat {
        return _balanceOf(who);
    };

    public query func totalSupply(): async Nat {
        return totalSupply_;
    };

    public query func getUserTokens(owner: Principal): async [TokenInfoExt] {
        let tokenIds = switch (users.get(owner)) {
            case (?user) { TrieSet.toArray(user.tokens); };
            case _ { [] };
        };
        let ret = Buffer.Buffer<TokenInfoExt>(tokenIds.size());
        for (id in Iter.fromArray(tokenIds)) {
            ret.add(_tokenInfotoExt(_unwrap(tokens.get(id))));
        };
        return ret.toArray();
    };

    // System functions
    system func preupgrade() {
        tokensEntries := Iter.toArray(tokens.entries());
        usersEntries := Iter.toArray(users.entries());
        salesEntries := Iter.toArray(sales.entries());
    };

    system func postupgrade() {
        tokens := HashMap.fromIter<Nat, TokenInfo>(tokensEntries.vals(), 1, Nat.equal, Hash.hash);
        users := HashMap.fromIter<Principal, UserInfo>(usersEntries.vals(), 1, Principal.equal, Principal.hash);
        sales := HashMap.fromIter<Nat, SaleInfo>(salesEntries.vals(), 1, Nat.equal, Hash.hash);
        tokensEntries := [];
        usersEntries := [];
        salesEntries := [];
    };
};