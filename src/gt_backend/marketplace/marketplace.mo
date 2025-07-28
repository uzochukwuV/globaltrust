import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Hash "mo:base/Hash";
import PropertyVerifier "canister:property";

actor PropertyMarketplace {
    // Configuration
    private let owner: Principal = Principal.fromText("aaaaa-aa"); // Replace with actual owner principal
    
    // Types
    public type PropertyListing = {
        id: Text;
        seller: Principal;
        submission_id: Text; // From PropertyVerifier
        title: Text;
        description: Text;
        property_type: Text; // "residential", "commercial", etc.
        location: Text;
        price: Nat; // In USD cents
        listing_type: ListingType;
        status: ListingStatus;
        timestamp: Nat64;
        end_date: ?Nat64; // For auctions
        reserve_price: ?Nat; // For auctions
        highest_bid: ?{ bidder: Principal; amount: Nat; timestamp: Nat64 };
        escrow_amount: Nat; // Funds held in escrow
        buyer: ?Principal; // Buyer for direct sale
    };

    public type ListingType = {
        #sale; // Fixed price sale
        #auction; // Auction with bidding
    };

    public type ListingStatus = {
        #active; // Available for offers/bids
        #pending; // Offer/bid accepted, awaiting escrow
        #in_escrow; // Funds in escrow, awaiting completion
        #completed; // Transaction finalized
        #cancelled; // Cancelled by seller or admin
        #disputed; // In dispute
    };

    public type Offer = {
        offer_id: Text;
        listing_id: Text;
        buyer: Principal;
        amount: Nat; // In USD cents
        timestamp: Nat64;
        status: OfferStatus;
    };

    public type OfferStatus = {
        #pending;
        #accepted;
        #rejected;
        #withdrawn;
    };

    public type Bid = {
        bid_id: Text;
        listing_id: Text;
        bidder: Principal;
        amount: Nat; // In USD cents
        timestamp: Nat64;
    };

    public type SellerProfile = {
        principal: Principal;
        total_listings: Nat;
        active_listings: Nat;
        completed_sales: Nat;
        reputation_score: Nat; // 1-100
        preferred_property_types: [Text];
        average_sale_price: Nat;
    };

    public type BuyerProfile = {
        principal: Principal;
        total_purchases: Nat;
        active_offers: Nat;
        active_bids: Nat;
        reputation_score: Nat; // 1-100
        preferred_property_types: [Text];
        max_budget: Nat;
    };

    public type EventLog = {
        event_id: Nat;
        timestamp: Nat64;
        event_type: EventType;
        description: Text;
        related_listing_id: ?Text;
        actor_principal: ?Principal;
        amount: ?Nat;
    };

    public type EventType = {
        #listing_created;
        #offer_submitted;
        #offer_accepted;
        #offer_rejected;
        #bid_placed;
        #auction_ended;
        #transaction_completed;
        #escrow_deposited;
        #escrow_released;
        #listing_cancelled;
        #dispute_raised;
        #dispute_resolved;
    };

    public type ListingResponse = {
        success: Bool;
        message: Text;
        listing_id: ?Text;
    };

    public type DashboardData = {
        seller_data: ?{
            active_listings: Nat;
            total_listed_value: Nat;
            completed_sales: Nat;
            reputation_score: Nat;
            pending_offers: Nat;
        };
        buyer_data: ?{
            active_offers: Nat;
            active_bids: Nat;
            total_purchased: Nat;
            reputation_score: Nat;
            available_listings: Nat;
        };
        market_data: {
            total_listings: Nat;
            total_value: Nat;
            average_price: Nat;
            active_auctions: Nat;
        };
    };

    public type ListingFilters = {
        status: ?ListingStatus;
        min_price: ?Nat;
        max_price: ?Nat;
        property_type: ?Text;
        location: ?Text;
        seller: ?Principal;
        listing_type: ?ListingType;
    };

    // Stable storage
    private stable var listings_entries: [(Text, PropertyListing)] = [];
    private stable var offers_entries: [(Text, Offer)] = [];
    private stable var bids_entries: [(Text, Bid)] = [];
    private stable var seller_profiles_entries: [(Principal, SellerProfile)] = [];
    private stable var buyer_profiles_entries: [(Principal, BuyerProfile)] = [];
    private stable var events_entries: [(Nat, EventLog)] = [];
    private stable var listing_counter: Nat = 0;
    private stable var offer_counter: Nat = 0;
    private stable var bid_counter: Nat = 0;
    private stable var event_counter: Nat = 0;
    private stable var settings_entries: [(Text, Text)] = [];

    // Runtime storage
    private var listings = HashMap.HashMap<Text, PropertyListing>(50, Text.equal, Text.hash);
    private var offers = HashMap.HashMap<Text, Offer>(100, Text.equal, Text.hash);
    private var bids = HashMap.HashMap<Text, Bid>(100, Text.equal, Text.hash);
    private var seller_profiles = HashMap.HashMap<Principal, SellerProfile>(20, Principal.equal, Principal.hash);
    private var buyer_profiles = HashMap.HashMap<Principal, BuyerProfile>(50, Principal.equal, Principal.hash);
    private var events = HashMap.HashMap<Nat, EventLog>(200, Nat.equal, Hash.hash);
    private var settings = HashMap.HashMap<Text, Text>(10, Text.equal, Text.hash);

    // Constants
    private let MINIMUM_PRICE: Nat = 1000_00; // $1,000
    private let MINIMUM_BID_INCREMENT: Nat = 500_00; // $500
    private let ESCROW_FEE_RATE: Float = 0.01; // 1% fee
    private let SECONDS_PER_DAY: Nat64 = 86_400_000_000_000; // Nanoseconds in a day

    // Helper functions
    private func logEvent(event_type: EventType, description: Text, listing_id: ?Text, actor_principal: ?Principal, amount: ?Nat) {
        let event: EventLog = {
            event_id = event_counter;
            timestamp = Nat64.fromIntWrap(Time.now());
            event_type = event_type;
            description = description;
            related_listing_id = listing_id;
            actor_principal = actor_principal;
            amount = amount;
        };
        events.put(event_counter, event);
        event_counter += 1;
    };

    // Initialize demo data
    private func initDemoData() {
        // Demo seller profile
        let demo_seller_profile: SellerProfile = {
            principal = Principal.fromText("2vxsx-fae");
            total_listings = 2;
            active_listings = 1;
            completed_sales = 1;
            reputation_score = 90;
            preferred_property_types = ["residential"];
            average_sale_price = 250_000_00; // $250,000
        };
        seller_profiles.put(Principal.fromText("2vxsx-fae"), demo_seller_profile);

        // Demo buyer profile
        let demo_buyer_profile: BuyerProfile = {
            principal = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            total_purchases = 1;
            active_offers = 1;
            active_bids = 0;
            reputation_score = 85;
            preferred_property_types = ["residential", "commercial"];
            max_budget = 500_000_00; // $500,000
        };
        buyer_profiles.put(Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai"), demo_buyer_profile);

        // Demo listing (sale)
        let demo_listing: PropertyListing = {
            id = "P001";
            seller = Principal.fromText("2vxsx-fae");
            submission_id = "S001";
            title = "123 Main St - Residential Home";
            description = "3-bedroom house, 2 baths, verified title";
            property_type = "residential";
            location = "123 Main St";
            price = 250_000_00; // $250,000
            listing_type = #sale;
            status = #active;
            timestamp = Nat64.fromIntWrap(Time.now());
            end_date = null;
            reserve_price = null;
            highest_bid = null;
            escrow_amount = 0;
            buyer = null;
        };
        listings.put("P001", demo_listing);

        // Demo listing (auction)
        let demo_auction: PropertyListing = {
            id = "P002";
            seller = Principal.fromText("2vxsx-fae");
            submission_id = "S002";
            title = "456 Oak Ave - Commercial Property";
            description = "Office building, prime location";
            property_type = "commercial";
            location = "456 Oak Ave";
            price = 300_000_00; // Starting price $300,000
            listing_type = #auction;
            status = #active;
            timestamp = Nat64.fromIntWrap(Time.now());
            end_date = ?(Nat64.fromIntWrap(Time.now()) + (7 * SECONDS_PER_DAY));
            reserve_price = ?350_000_00; // Reserve $350,000
            highest_bid = null;
            escrow_amount = 0;
            buyer = null;
        };
        listings.put("P002", demo_auction);

        logEvent(#listing_created, "Initialized demo listing P001", ?"P001", null, ?250_000_00);
        logEvent(#listing_created, "Initialized demo auction P002", ?"P002", null, ?300_000_00);
        listing_counter := 2;
    };

    initDemoData();

    // Upgrade hooks
    system func preupgrade() {
        listings_entries := Iter.toArray(listings.entries());
        offers_entries := Iter.toArray(offers.entries());
        bids_entries := Iter.toArray(bids.entries());
        seller_profiles_entries := Iter.toArray(seller_profiles.entries());
        buyer_profiles_entries := Iter.toArray(buyer_profiles.entries());
        events_entries := Iter.toArray(events.entries());
        settings_entries := Iter.toArray(settings.entries());
    };

    system func postupgrade() {
        listings := HashMap.fromIter<Text, PropertyListing>(listings_entries.vals(), listings_entries.size(), Text.equal, Text.hash);
        offers := HashMap.fromIter<Text, Offer>(offers_entries.vals(), offers_entries.size(), Text.equal, Text.hash);
        bids := HashMap.fromIter<Text, Bid>(bids_entries.vals(), bids_entries.size(), Text.equal, Text.hash);
        seller_profiles := HashMap.fromIter<Principal, SellerProfile>(seller_profiles_entries.vals(), seller_profiles_entries.size(), Principal.equal, Principal.hash);
        buyer_profiles := HashMap.fromIter<Principal, BuyerProfile>(buyer_profiles_entries.vals(), buyer_profiles_entries.size(), Principal.equal, Principal.hash);
        events := HashMap.fromIter<Nat, EventLog>(events_entries.vals(), events_entries.size(), Nat.equal, Hash.hash);
        settings := HashMap.fromIter<Text, Text>(settings_entries.vals(), settings_entries.size(), Text.equal, Text.hash);
        listings_entries := [];
        offers_entries := [];
        bids_entries := [];
        seller_profiles_entries := [];
        buyer_profiles_entries := [];
        events_entries := [];
        settings_entries := [];
    };

    // Create a property listing
    public shared(msg) func createListing(
        submission_id: Text,
        title: Text,
        description: Text,
        property_type: Text,
        location: Text,
        price: Nat,
        listing_type: ListingType,
        auction_duration: ?Nat64, // Days for auction
        reserve_price: ?Nat
    ) : async ListingResponse {
        if (price < MINIMUM_PRICE) {
            return {
                success = false;
                message = "Price must be at least $1,000";
                listing_id = null;
            };
        };

        // Validate property with PropertyVerifier
        let submission = await PropertyVerifier.getSubmissionById(submission_id);
        switch (submission) {
            case null {
                return {
                    success = false;
                    message = "Property submission not found";
                    listing_id = null;
                };
            };
            case (?sub) {
                if (sub.status != #verified) {
                    return {
                        success = false;
                        message = "Property must be verified";
                        listing_id = null;
                    };
                };
                let verification = await PropertyVerifier.getVerificationResult(submission_id);
                switch (verification) {
                    case null {
                        return {
                            success = false;
                            message = "Property verification result not found";
                            listing_id = null;
                        };
                    };
                    case (?ver) {
                        if (ver.verdict != #valid) {
                            return {
                                success = false;
                                message = "Property must have a valid verdict";
                                listing_id = null;
                            };
                        };
                    };
                };
            };
        };

        // Validate auction parameters
        let end_date = switch (listing_type, auction_duration) {
            case (#auction, ?days) { ?(Nat64.fromIntWrap(Time.now()) + (days * SECONDS_PER_DAY)) };
            case (#auction, null) {
                return {
                    success = false;
                    message = "Auction duration must be specified";
                    listing_id = null;
                };
            };
            case (#sale, _) { null };
        };
        let reserve = switch (listing_type) {
            case (#auction) { reserve_price };
            case (#sale) { null };
        };

        // Create listing
        listing_counter += 1;
        let listing_id = "P" # Nat.toText(listing_counter);
        let listing: PropertyListing = {
            id = listing_id;
            seller = msg.caller;
            submission_id = submission_id;
            title = title;
            description = description;
            property_type = property_type;
            location = location;
            price = price;
            listing_type = listing_type;
            status = #active;
            timestamp = Nat64.fromIntWrap(Time.now());
            end_date = end_date;
            reserve_price = reserve;
            highest_bid = null;
            escrow_amount = 0;
            buyer = null;
        };
        listings.put(listing_id, listing);

        // Update seller profile
        switch (seller_profiles.get(msg.caller)) {
            case null {
                let new_profile: SellerProfile = {
                    principal = msg.caller;
                    total_listings = 1;
                    active_listings = 1;
                    completed_sales = 0;
                    reputation_score = 50;
                    preferred_property_types = [property_type];
                    average_sale_price = price;
                };
                seller_profiles.put(msg.caller, new_profile);
            };
            case (?profile) {
                let updated_profile: SellerProfile = {
                    principal = profile.principal;
                    total_listings = profile.total_listings + 1;
                    active_listings = profile.active_listings + 1;
                    completed_sales = profile.completed_sales;
                    reputation_score = profile.reputation_score;
                    preferred_property_types = Array.append(profile.preferred_property_types, [property_type]);
                    average_sale_price = (profile.average_sale_price * profile.total_listings + price) / (profile.total_listings + 1);
                };
                seller_profiles.put(msg.caller, updated_profile);
            };
        };

        logEvent(#listing_created, "Listing created: " # listing_id, ?listing_id, ?msg.caller, ?price);
        {
            success = true;
            message = "Listing created successfully";
            listing_id = ?listing_id;
        }
    };

    // Submit an offer for a sale listing
    public shared(msg) func submitOffer(listing_id: Text, amount: Nat) : async Result.Result<Text, Text> {
        switch (listings.get(listing_id)) {
            case null {
                return #err("Listing not found");
            };
            case (?listing) {
                if (listing.status != #active) {
                    return #err("Listing is not active");
                };
                if (listing.listing_type != #sale) {
                    return #err("Offers can only be submitted for sale listings");
                };
                if (Principal.equal(listing.seller, msg.caller)) {
                    return #err("Seller cannot submit an offer for their own listing");
                };
                if (amount < MINIMUM_PRICE) {
                    return #err("Offer amount must be at least $1,000");
                };

                // Create offer
                offer_counter += 1;
                let offer_id = "O" # Nat.toText(offer_counter);
                let offer: Offer = {
                    offer_id = offer_id;
                    listing_id = listing_id;
                    buyer = msg.caller;
                    amount = amount;
                    timestamp = Nat64.fromIntWrap(Time.now());
                    status = #pending;
                };
                offers.put(offer_id, offer);

                // Update buyer profile
                switch (buyer_profiles.get(msg.caller)) {
                    case null {
                        let new_profile: BuyerProfile = {
                            principal = msg.caller;
                            total_purchases = 0;
                            active_offers = 1;
                            active_bids = 0;
                            reputation_score = 50;
                            preferred_property_types = [listing.property_type];
                            max_budget = amount;
                        };
                        buyer_profiles.put(msg.caller, new_profile);
                    };
                    case (?profile) {
                        let updated_profile: BuyerProfile = {
                            principal = profile.principal;
                            total_purchases = profile.total_purchases;
                            active_offers = profile.active_offers + 1;
                            active_bids = profile.active_bids;
                            reputation_score = profile.reputation_score;
                            preferred_property_types = Array.append(profile.preferred_property_types, [listing.property_type]);
                            max_budget = Nat.max(profile.max_budget, amount);
                        };
                        buyer_profiles.put(msg.caller, updated_profile);
                    };
                };

                logEvent(#offer_submitted, "Offer submitted: " # offer_id # " for listing " # listing_id, ?listing_id, ?msg.caller, ?amount);
                #ok(offer_id)
            };
        }
    };

    // Place a bid on an auction listing
    public shared(msg) func placeBid(listing_id: Text, amount: Nat) : async Result.Result<Text, Text> {
        switch (listings.get(listing_id)) {
            case null {
                return #err("Listing not found");
            };
            case (?listing) {
                if (listing.status != #active) {
                    return #err("Listing is not active");
                };
                if (listing.listing_type != #auction) {
                    return #err("Bids can only be placed on auction listings");
                };
                if (Principal.equal(listing.seller, msg.caller)) {
                    return #err("Seller cannot bid on their own auction");
                };
                if (amount < listing.price) {
                    return #err("Bid amount must be at least the starting price");
                };
                switch (listing.highest_bid) {
                    case (?bid) {
                        if (amount < bid.amount + MINIMUM_BID_INCREMENT) {
                            return #err("Bid must be at least $" # Nat.toText(MINIMUM_BID_INCREMENT / 100) # " higher than current highest bid");
                        };
                    };
                    case null { };
                };
                switch (listing.end_date) {
                    case (?end) {
                        if (Nat64.fromIntWrap(Time.now()) > end) {
                            return #err("Auction has ended");
                        };
                    };
                    case null { };
                };

                // Create bid
                bid_counter += 1;
                let bid_id = "B" # Nat.toText(bid_counter);
                let bid: Bid = {
                    bid_id = bid_id;
                    listing_id = listing_id;
                    bidder = msg.caller;
                    amount = amount;
                    timestamp = Nat64.fromIntWrap(Time.now());
                };
                bids.put(bid_id, bid);

                // Update listing with highest bid
                let updated_listing: PropertyListing = {
                    id = listing.id;
                    seller = listing.seller;
                    submission_id = listing.submission_id;
                    title = listing.title;
                    description = listing.description;
                    property_type = listing.property_type;
                    location = listing.location;
                    price = listing.price;
                    listing_type = listing.listing_type;
                    status = listing.status;
                    timestamp = listing.timestamp;
                    end_date = listing.end_date;
                    reserve_price = listing.reserve_price;
                    highest_bid = ?{ bidder = msg.caller; amount = amount; timestamp = Nat64.fromIntWrap(Time.now()) };
                    escrow_amount = listing.escrow_amount;
                    buyer = listing.buyer;
                };
                listings.put(listing_id, updated_listing);

                // Update buyer profile
                switch (buyer_profiles.get(msg.caller)) {
                    case null {
                        let new_profile: BuyerProfile = {
                            principal = msg.caller;
                            total_purchases = 0;
                            active_offers = 0;
                            active_bids = 1;
                            reputation_score = 50;
                            preferred_property_types = [listing.property_type];
                            max_budget = amount;
                        };
                        buyer_profiles.put(msg.caller, new_profile);
                    };
                    case (?profile) {
                        let updated_profile: BuyerProfile = {
                            principal = profile.principal;
                            total_purchases = profile.total_purchases;
                            active_offers = profile.active_offers;
                            active_bids = profile.active_bids + 1;
                            reputation_score = profile.reputation_score;
                            preferred_property_types = Array.append(profile.preferred_property_types, [listing.property_type]);
                            max_budget = Nat.max(profile.max_budget, amount);
                        };
                        buyer_profiles.put(msg.caller, updated_profile);
                    };
                };

                logEvent(#bid_placed, "Bid placed: " # bid_id # " for listing " # listing_id, ?listing_id, ?msg.caller, ?amount);
                #ok(bid_id)
            };
        }
    };

    // Accept an offer
    public shared(msg) func acceptOffer(offer_id: Text) : async Result.Result<Text, Text> {
        switch (offers.get(offer_id)) {
            case null {
                return #err("Offer not found");
            };
            case (?offer) {
                switch (listings.get(offer.listing_id)) {
                    case null {
                        return #err("Listing not found");
                    };
                    case (?listing) {
                        if (not Principal.equal(listing.seller, msg.caller)) {
                            return #err("Only the seller can accept offers");
                        };
                        if (listing.status != #active) {
                            return #err("Listing is not active");
                        };
                        if (offer.status != #pending) {
                            return #err("Offer is not pending");
                        };

                        // Update offer
                        let updated_offer: Offer = {
                            offer_id = offer.offer_id;
                            listing_id = offer.listing_id;
                            buyer = offer.buyer;
                            amount = offer.amount;
                            timestamp = offer.timestamp;
                            status = #accepted;
                        };
                        offers.put(offer_id, updated_offer);

                        // Update listing
                        let escrow_amount = Float.toInt(Float.fromInt(offer.amount) * ESCROW_FEE_RATE);
                        let updated_listing: PropertyListing = {
                            id = listing.id;
                            seller = listing.seller;
                            submission_id = listing.submission_id;
                            title = listing.title;
                            description = listing.description;
                            property_type = listing.property_type;
                            location = listing.location;
                            price = listing.price;
                            listing_type = listing.listing_type;
                            status = #pending;
                            timestamp = listing.timestamp;
                            end_date = listing.end_date;
                            reserve_price = listing.reserve_price;
                            highest_bid = listing.highest_bid;
                            escrow_amount = Nat64.toNat(Nat64.fromIntWrap(escrow_amount));
                            buyer = ?offer.buyer;
                        };
                        listings.put(listing.id, updated_listing);

                        logEvent(#offer_accepted, "Offer " # offer_id # " accepted for listing " # listing.id, ?listing.id, ?msg.caller, ?offer.amount);
                        #ok("Offer accepted, proceed to deposit escrow")
                    };
                }
            };
        }
    };

    // Deposit escrow (simulated)
    public shared(msg) func depositEscrow(listing_id: Text) : async Result.Result<Text, Text> {
        switch (listings.get(listing_id)) {
            case null {
                return #err("Listing not found");
            };
            case (?listing) {
                if (listing.status != #pending) {
                    return #err("Listing is not in pending status");
                };
                switch (listing.buyer) {
                    case null {
                        return #err("No buyer assigned to listing");
                    };
                    case (?buyer) {
                        if (not Principal.equal(buyer, msg.caller)) {
                            return #err("Only the assigned buyer can deposit escrow");
                        };
                    };
                };

                // Update listing to in_escrow
                let updated_listing: PropertyListing = {
                    id = listing.id;
                    seller = listing.seller;
                    submission_id = listing.submission_id;
                    title = listing.title;
                    description = listing.description;
                    property_type = listing.property_type;
                    location = listing.location;
                    price = listing.price;
                    listing_type = listing.listing_type;
                    status = #in_escrow;
                    timestamp = listing.timestamp;
                    end_date = listing.end_date;
                    reserve_price = listing.reserve_price;
                    highest_bid = listing.highest_bid;
                    escrow_amount = listing.escrow_amount;
                    buyer = listing.buyer;
                };
                listings.put(listing_id, updated_listing);

                logEvent(#escrow_deposited, "Escrow deposited for listing " # listing_id, ?listing_id, ?msg.caller, ?listing.escrow_amount);
                #ok("Escrow deposited successfully")
            };
        }
    };

    // Finalize transaction
    public shared(msg) func finalizeTransaction(listing_id: Text) : async Result.Result<Text, Text> {
        switch (listings.get(listing_id)) {
            case null {
                return #err("Listing not found");
            };
            case (?listing) {
                if (not Principal.equal(listing.seller, msg.caller) and not Principal.equal(owner, msg.caller)) {
                    return #err("Only the seller or admin can finalize the transaction");
                };
                if (listing.status != #in_escrow) {
                    return #err("Listing is not in escrow");
                };

                // Update listing
                let updated_listing: PropertyListing = {
                    id = listing.id;
                    seller = listing.seller;
                    submission_id = listing.submission_id;
                    title = listing.title;
                    description = listing.description;
                    property_type = listing.property_type;
                    location = listing.location;
                    price = listing.price;
                    listing_type = listing.listing_type;
                    status = #completed;
                    timestamp = listing.timestamp;
                    end_date = listing.end_date;
                    reserve_price = listing.reserve_price;
                    highest_bid = listing.highest_bid;
                    escrow_amount = listing.escrow_amount;
                    buyer = listing.buyer;
                };
                listings.put(listing_id, updated_listing);

                // Update seller profile
                switch (seller_profiles.get(listing.seller)) {
                    case (?profile) {
                        let updated_profile: SellerProfile = {
                            principal = profile.principal;
                            total_listings = profile.total_listings;
                            active_listings = if (profile.active_listings > 0) { profile.active_listings - 1 } else { 0 };
                            completed_sales = profile.completed_sales + 1;
                            reputation_score = Nat.min(100, profile.reputation_score + 5);
                            preferred_property_types = profile.preferred_property_types;
                            average_sale_price = (profile.average_sale_price * profile.completed_sales + listing.price) / (profile.completed_sales + 1);
                        };
                        seller_profiles.put(listing.seller, updated_profile);
                    };
                    case null { };
                };

                // Update buyer profile
                switch (listing.buyer) {
                    case (?buyer) {
                        switch (buyer_profiles.get(buyer)) {
                            case (?profile) {
                                let updated_profile: BuyerProfile = {
                                    principal = profile.principal;
                                    total_purchases = profile.total_purchases + 1;
                                    active_offers = if (profile.active_offers > 0) { profile.active_offers - 1 } else { 0 };
                                    active_bids = profile.active_bids;
                                    reputation_score = Nat.min(100, profile.reputation_score + 5);
                                    preferred_property_types = profile.preferred_property_types;
                                    max_budget = profile.max_budget;
                                };
                                buyer_profiles.put(buyer, updated_profile);
                            };
                            case null { };
                        };
                    };
                    case null { };
                };

                logEvent(#transaction_completed, "Transaction completed for listing " # listing_id, ?listing_id, ?msg.caller, ?listing.price);
                #ok("Transaction finalized successfully")
            };
        }
    };

    // End an auction
    public shared(msg) func endAuction(listing_id: Text) : async Result.Result<Text, Text> {
        switch (listings.get(listing_id)) {
            case null {
                return #err("Listing not found");
            };
            case (?listing) {
                if (not Principal.equal(listing.seller, msg.caller) and not Principal.equal(owner, msg.caller)) {
                    return #err("Only the seller or admin can end the auction");
                };
                if (listing.listing_type != #auction) {
                    return #err("Listing is not an auction");
                };
                if (listing.status != #active) {
                    return #err("Auction is not active");
                };
                switch (listing.end_date) {
                    case (?end) {
                        if (Nat64.fromIntWrap(Time.now()) < end) {
                            return #err("Auction has not yet ended");
                        };
                    };
                    case null {
                        return #err("Auction end date not set");
                    };
                };

                // Check if reserve price is met
                let meets_reserve = switch (listing.highest_bid, listing.reserve_price) {
                    case (?bid, ?reserve) { bid.amount >= reserve };
                    case (?bid, null) { true };
                    case (null, _) { false };
                };

                if (meets_reserve) {
                    switch (listing.highest_bid) {
                        case (?bid) {
                            let escrow_amount = Float.toInt(Float.fromInt(bid.amount) * ESCROW_FEE_RATE);
                            let updated_listing: PropertyListing = {
                                id = listing.id;
                                seller = listing.seller;
                                submission_id = listing.submission_id;
                                title = listing.title;
                                description = listing.description;
                                property_type = listing.property_type;
                                location = listing.location;
                                price = listing.price;
                                listing_type = listing.listing_type;
                                status = #pending;
                                timestamp = listing.timestamp;
                                end_date = listing.end_date;
                                reserve_price = listing.reserve_price;
                                highest_bid = listing.highest_bid;
                                escrow_amount = Nat64.toNat(Nat64.fromIntWrap(escrow_amount));
                                buyer = ?bid.bidder;
                            };
                            listings.put(listing_id, updated_listing);

                            // Update buyer profile
                            switch (buyer_profiles.get(bid.bidder)) {
                                case (?profile) {
                                    let updated_profile: BuyerProfile = {
                                        principal = profile.principal;
                                        total_purchases = profile.total_purchases;
                                        active_offers = profile.active_offers;
                                        active_bids = if (profile.active_bids > 0) { profile.active_bids - 1 } else { 0 };
                                        reputation_score = profile.reputation_score;
                                        preferred_property_types = profile.preferred_property_types;
                                        max_budget = profile.max_budget;
                                    };
                                    buyer_profiles.put(bid.bidder, updated_profile);
                                };
                                case null { };
                            };

                            logEvent(#auction_ended, "Auction ended for listing " # listing_id # ", winner: " # Principal.toText(bid.bidder), ?listing_id, ?msg.caller, ?bid.amount);
                            #ok("Auction ended, winner assigned. Proceed to deposit escrow.")
                        };
                        case null {
                            let updated_listing: PropertyListing = {
                                id = listing.id;
                                seller = listing.seller;
                                submission_id = listing.submission_id;
                                title = listing.title;
                                description = listing.description;
                                property_type = listing.property_type;
                                location = listing.location;
                                price = listing.price;
                                listing_type = listing.listing_type;
                                status = #cancelled;
                                timestamp = listing.timestamp;
                                end_date = listing.end_date;
                                reserve_price = listing.reserve_price;
                                highest_bid = listing.highest_bid;
                                escrow_amount = 0;
                                buyer = null;
                            };
                            listings.put(listing_id, updated_listing);
                            logEvent(#auction_ended, "Auction ended for listing " # listing_id # ", no bids", ?listing_id, ?msg.caller, null);
                            #ok("Auction ended with no valid bids")
                        };
                    }
                } else {
                    let updated_listing: PropertyListing = {
                        id = listing.id;
                        seller = listing.seller;
                        submission_id = listing.submission_id;
                        title = listing.title;
                        description = listing.description;
                        property_type = listing.property_type;
                        location = listing.location;
                        price = listing.price;
                        listing_type = listing.listing_type;
                        status = #cancelled;
                        timestamp = listing.timestamp;
                        end_date = listing.end_date;
                        reserve_price = listing.reserve_price;
                        highest_bid = listing.highest_bid;
                        escrow_amount = 0;
                        buyer = null;
                    };
                    listings.put(listing_id, updated_listing);
                    logEvent(#auction_ended, "Auction ended for listing " # listing_id # ", reserve price not met", ?listing_id, ?msg.caller, null);
                    #ok("Auction ended, reserve price not met")
                }
            };
        }
    };

    // Cancel a listing
    public shared(msg) func cancelListing(listing_id: Text) : async Result.Result<Text, Text> {
        switch (listings.get(listing_id)) {
            case null {
                return #err("Listing not found");
            };
            case (?listing) {
                if (not Principal.equal(listing.seller, msg.caller) and not Principal.equal(owner, msg.caller)) {
                    return #err("Only the seller or admin can cancel the listing");
                };
                if (listing.status != #active) {
                    return #err("Listing is not active");
                };

                let updated_listing: PropertyListing = {
                    id = listing.id;
                    seller = listing.seller;
                    submission_id = listing.submission_id;
                    title = listing.title;
                    description = listing.description;
                    property_type = listing.property_type;
                    location = listing.location;
                    price = listing.price;
                    listing_type = listing.listing_type;
                    status = #cancelled;
                    timestamp = listing.timestamp;
                    end_date = listing.end_date;
                    reserve_price = listing.reserve_price;
                    highest_bid = listing.highest_bid;
                    escrow_amount = 0;
                    buyer = null;
                };
                listings.put(listing_id, updated_listing);

                // Update seller profile
                switch (seller_profiles.get(listing.seller)) {
                    case (?profile) {
                        let updated_profile: SellerProfile = {
                            principal = profile.principal;
                            total_listings = profile.total_listings;
                            active_listings = if (profile.active_listings > 0) { profile.active_listings - 1 } else { 0 };
                            completed_sales = profile.completed_sales;
                            reputation_score = Nat.max(0, profile.reputation_score - 2);
                            preferred_property_types = profile.preferred_property_types;
                            average_sale_price = profile.average_sale_price;
                        };
                        seller_profiles.put(listing.seller, updated_profile);
                    };
                    case null { };
                };

                logEvent(#listing_cancelled, "Listing " # listing_id # " cancelled", ?listing_id, ?msg.caller, null);
                #ok("Listing cancelled successfully")
            };
        }
    };

    // Resolve a dispute
    public shared(msg) func resolveDispute(listing_id: Text, release_to_buyer: Bool) : async Result.Result<Text, Text> {
        if (not Principal.equal(owner, msg.caller)) {
            return #err("Only the admin can resolve disputes");
        };
        switch (listings.get(listing_id)) {
            case null {
                return #err("Listing not found");
            };
            case (?listing) {
                if (listing.status != #in_escrow and listing.status != #disputed) {
                    return #err("Listing is not in escrow or disputed status");
                };

                let new_status = if (release_to_buyer) { #completed } else { #cancelled };
                let updated_listing: PropertyListing = {
                    id = listing.id;
                    seller = listing.seller;
                    submission_id = listing.submission_id;
                    title = listing.title;
                    description = listing.description;
                    property_type = listing.property_type;
                    location = listing.location;
                    price = listing.price;
                    listing_type = listing.listing_type;
                    status = new_status;
                    timestamp = listing.timestamp;
                    end_date = listing.end_date;
                    reserve_price = listing.reserve_price;
                    highest_bid = listing.highest_bid;
                    escrow_amount = listing.escrow_amount;
                    buyer = listing.buyer;
                };
                listings.put(listing_id, updated_listing);

                // Update profiles based on resolution
                if (new_status == #completed) {
                    switch (seller_profiles.get(listing.seller)) {
                        case (?profile) {
                            let updated_profile: SellerProfile = {
                                principal = profile.principal;
                                total_listings = profile.total_listings;
                                active_listings = if (profile.active_listings > 0) { profile.active_listings - 1 } else { 0 };
                                completed_sales = profile.completed_sales + 1;
                                reputation_score = Nat.min(100, profile.reputation_score + 2);
                                preferred_property_types = profile.preferred_property_types;
                                average_sale_price = (profile.average_sale_price * profile.completed_sales + listing.price) / (profile.completed_sales + 1);
                            };
                            seller_profiles.put(listing.seller, updated_profile);
                        };
                        case null { };
                    };
                    switch (listing.buyer) {
                        case (?buyer) {
                            switch (buyer_profiles.get(buyer)) {
                                case (?profile) {
                                    let updated_profile: BuyerProfile = {
                                        principal = profile.principal;
                                        total_purchases = profile.total_purchases + 1;
                                        active_offers = if (profile.active_offers > 0) { profile.active_offers - 1 } else { 0 };
                                        active_bids = profile.active_bids;
                                        reputation_score = Nat.min(100, profile.reputation_score + 2);
                                        preferred_property_types = profile.preferred_property_types;
                                        max_budget = profile.max_budget;
                                    };
                                    buyer_profiles.put(buyer, updated_profile);
                                };
                                case null { };
                            };
                        };
                        case null { };
                    };
                } else {
                    switch (seller_profiles.get(listing.seller)) {
                        case (?profile) {
                            let updated_profile: SellerProfile = {
                                principal = profile.principal;
                                total_listings = profile.total_listings;
                                active_listings = if (profile.active_listings > 0) { profile.active_listings - 1 } else { 0 };
                                completed_sales = profile.completed_sales;
                                reputation_score = Nat.max(0, profile.reputation_score - 5);
                                preferred_property_types = profile.preferred_property_types;
                                average_sale_price = profile.average_sale_price;
                            };
                            seller_profiles.put(listing.seller, updated_profile);
                        };
                        case null { };
                    };
                    switch (listing.buyer) {
                        case (?buyer) {
                            switch (buyer_profiles.get(buyer)) {
                                case (?profile) {
                                    let updated_profile: BuyerProfile = {
                                        principal = profile.principal;
                                        total_purchases = profile.total_purchases;
                                        active_offers = if (profile.active_offers > 0) { profile.active_offers - 1 } else { 0 };
                                        active_bids = profile.active_bids;
                                        reputation_score = Nat.max(0, profile.reputation_score - 5);
                                        preferred_property_types = profile.preferred_property_types;
                                        max_budget = profile.max_budget;
                                    };
                                    buyer_profiles.put(buyer, updated_profile);
                                };
                                case null { };
                            };
                        };
                        case null { };
                    };
                };

                logEvent(#dispute_resolved, "Dispute resolved for listing " # listing_id # ", funds released to " # (if release_to_buyer { "buyer" } else { "seller" }), ?listing_id, ?msg.caller, ?listing.escrow_amount);
                #ok("Dispute resolved successfully")
            };
        }
    };

    // Query functions
    public query func getAllListings(filters: ?ListingFilters) : async [PropertyListing] {
        let all_listings = Array.map<(Text, PropertyListing), PropertyListing>(
            Iter.toArray(listings.entries()),
            func((id, listing)) = listing
        );
        switch (filters) {
            case null { all_listings };
            case (?f) {
                Array.filter<PropertyListing>(all_listings, func(listing) {
                    let status_match = switch (f.status) {
                        case (?s) { listing.status == s };
                        case null { true };
                    };
                    let min_price_match = switch (f.min_price) {
                        case (?p) { listing.price >= p };
                        case null { true };
                    };
                    let max_price_match = switch (f.max_price) {
                        case (?p) { listing.price <= p };
                        case null { true };
                    };
                    let property_type_match = switch (f.property_type) {
                        case (?pt) { listing.property_type == pt };
                        case null { true };
                    };
                    let location_match = switch (f.location) {
                        case (?loc) { listing.location == loc };
                        case null { true };
                    };
                    let seller_match = switch (f.seller) {
                        case (?s) { Principal.equal(listing.seller, s) };
                        case null { true };
                    };
                    let listing_type_match = switch (f.listing_type) {
                        case (?lt) { listing.listing_type == lt };
                        case null { true };
                    };
                    status_match and min_price_match and max_price_match and property_type_match and
                    location_match and seller_match and listing_type_match
                });
            };
        }
    };

    public query func getListingById(listing_id: Text) : async ?PropertyListing {
        listings.get(listing_id)
    };

    public query func getOffersByListing(listing_id: Text) : async [Offer] {
        Array.filter<Offer>(
            Array.map<(Text, Offer), Offer>(
                Iter.toArray(offers.entries()),
                func((id, offer)) = offer
            ),
            func(offer) = offer.listing_id == listing_id
        )
    };

    public query func getBidsByListing(listing_id: Text) : async [Bid] {
        Array.filter<Bid>(
            Array.map<(Text, Bid), Bid>(
                Iter.toArray(bids.entries()),
                func((id, bid)) = bid
            ),
            func(bid) = bid.listing_id == listing_id
        )
    };

    public query func getDashboardData(principal: Principal) : async DashboardData {
        let seller_listings = Array.filter<PropertyListing>(
            Array.map<(Text, PropertyListing), PropertyListing>(
                Iter.toArray(listings.entries()),
                func((id, listing)) = listing
            ),
            func(listing) = Principal.equal(listing.seller, principal) and listing.status == #active
        );
        let buyer_offers = Array.filter<Offer>(
            Array.map<(Text, Offer), Offer>(
                Iter.toArray(offers.entries()),
                func((id, offer)) = offer
            ),
            func(offer) = Principal.equal(offer.buyer, principal) and offer.status == #pending
        );
        let buyer_bids = Array.filter<Bid>(
            Array.map<(Text, Bid), Bid>(
                Iter.toArray(bids.entries()),
                func((id, bid)) = bid
            ),
            func(bid) = Principal.equal(bid.bidder, principal)
        );
        let available_listings = Array.filter<PropertyListing>(
            Array.map<(Text, PropertyListing), PropertyListing>(
                Iter.toArray(listings.entries()),
                func((id, listing)) = listing
            ),
            func(listing) = listing.status == #active
        );

        let seller_data = if (seller_listings.size() > 0 or seller_profiles.get(principal) != null) {
            let profile = Option.get(seller_profiles.get(principal), {
                principal = principal;
                total_listings = 0;
                active_listings = 0;
                completed_sales = 0;
                reputation_score = 50;
                preferred_property_types = [];
                average_sale_price = 0;
            });
            let total_value = Array.foldLeft<PropertyListing, Nat>(seller_listings, 0, func(sum, listing) = sum + listing.price);
            ?{
                active_listings = profile.active_listings;
                total_listed_value = total_value;
                completed_sales = profile.completed_sales;
                reputation_score = profile.reputation_score;
                pending_offers = buyer_offers.size();
            }
        } else {
            null
        };

        let buyer_data = if (buyer_offers.size() > 0 or buyer_bids.size() > 0 or buyer_profiles.get(principal) != null) {
            let profile = Option.get(buyer_profiles.get(principal), {
                principal = principal;
                total_purchases = 0;
                active_offers = 0;
                active_bids = 0;
                reputation_score = 50;
                preferred_property_types = [];
                max_budget = 0;
            });
            ?{
                active_offers = profile.active_offers;
                active_bids = profile.active_bids;
                total_purchased = profile.total_purchases;
                reputation_score = profile.reputation_score;
                available_listings = available_listings.size();
            }
        } else {
            null
        };

        let all_listings = Array.map<(Text, PropertyListing), PropertyListing>(
            Iter.toArray(listings.entries()),
            func((id, listing)) = listing
        );
        let total_value = Array.foldLeft<PropertyListing, Nat>(all_listings, 0, func(sum, listing) = sum + listing.price);
        let active_auctions = Array.filter<PropertyListing>(all_listings, func(listing) = listing.listing_type == #auction and listing.status == #active);
        let average_price = if (all_listings.size() > 0) {
            total_value / all_listings.size()
        } else {
            0
        };

        {
            seller_data = seller_data;
            buyer_data = buyer_data;
            market_data = {
                total_listings = all_listings.size();
                total_value = total_value;
                average_price = average_price;
                active_auctions = active_auctions.size();
            };
        }
    };

    public query func getEventLogs() : async [EventLog] {
        Array.map<(Nat, EventLog), EventLog>(
            Iter.toArray(events.entries()),
            func((id, event)) = event
        )
    };

    public query func getSellerProfile(principal: Principal) : async ?SellerProfile {
        seller_profiles.get(principal)
    };

    public query func getBuyerProfile(principal: Principal) : async ?BuyerProfile {
        buyer_profiles.get(principal)
    };

    // Admin function to update settings
    public shared(msg) func updateSettings(key: Text, value: Text) : async Result.Result<Text, Text> {
        if (not Principal.equal(owner, msg.caller)) {
            return #err("Unauthorized: Only the canister owner can update settings");
        };
        settings.put(key, value);
        logEvent(#listing_created, "Setting updated: " # key # " = " # value, null, ?msg.caller, null);
        #ok("Setting updated successfully")
    };
}