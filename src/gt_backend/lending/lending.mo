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

shared(msg) actor class LendingBorrowing() = this {
    // Configuration
    private let owner : Principal = msg.caller; // Replace with actual owner principal

    // Enhanced Types
    public type LoanRequest = {
        id : Text;
        borrower : Principal;
        submission_id : Text; // Property submission ID from PropertyVerifier
        amount : Nat; // Loan amount in USD cents
        duration : Nat64; // Loan duration in days
        interest_rate : Float; // Annual interest rate
        timestamp : Nat64;
        status : LoanStatus;
        lender : ?Principal;
        collateral_value : ?Nat; // Estimated property value in USD cents
        monthly_payment : Nat; // Monthly payment amount in USD cents
        payments_made : Nat; // Number of payments made
        total_payments : Nat; // Total number of payments required
        due_date : ?Nat64; // When the loan is due
        credit_score : ?Nat; // Borrower's credit score (0-850)
        loan_purpose : Text; // Purpose of the loan
        employment_verification : Bool; // Whether employment is verified
        income_verification : Bool; // Whether income is verified
        debt_to_income_ratio : ?Float; // Debt-to-income ratio
    };

    public type LoanStatus = {
        #pending; // Waiting for approval/funding
        #under_review; // Being reviewed by lenders
        #approved; // Approved but not funded
        #funded; // Funded and active
        #repaying; // Currently being repaid
        #repaid; // Fully repaid
        #defaulted; // In default
        #foreclosed; // Foreclosure initiated
        #rejected; // Rejected by lenders/admin
    };

    public type PaymentRecord = {
        payment_id : Text;
        loan_id : Text;
        amount : Nat;
        payment_date : Nat64;
        payment_type : PaymentType;
        late_fee : Nat;
        principal_amount : Nat;
        interest_amount : Nat;
        remaining_balance : Nat;
    };

    public type PaymentType = {
        #regular; // Regular monthly payment
        #extra; // Extra payment toward principal
        #late; // Late payment with fees
        #final; // Final payment
    };

    public type LenderProfile = {
        principal : Principal;
        total_invested : Nat;
        active_loans : Nat;
        completed_loans : Nat;
        default_rate : Float;
        average_return : Float;
        reputation_score : Nat; // 1-100
        preferred_loan_types : [Text];
        max_loan_amount : Nat;
        min_credit_score : Nat;
    };

    public type BorrowerProfile = {
        principal : Principal;
        credit_score : Nat;
        verified_income : ?Nat; // Monthly income in USD cents
        debt_to_income_ratio : Float;
        employment_status : Text;
        loan_history : [Text]; // Array of loan IDs
        payment_history_score : Nat; // 1-100
        properties_owned : [Text]; // Array of property submission IDs
    };

    public type LoanApplication = {
        borrower : Principal;
        requested_amount : Nat;
        loan_purpose : Text;
        employment_info : EmploymentInfo;
        financial_info : FinancialInfo;
        property_info : PropertyInfo;
        additional_documents : [Text]; // IPFS hashes or URLs
        duration : Nat64;
    };

    public type EmploymentInfo = {
        employer_name : Text;
        job_title : Text;
        employment_duration : Nat64; // in months
        monthly_income : Nat;
        employment_type : Text; // "full-time", "part-time", "self-employed", etc.
        verified : Bool;
    };

    public type FinancialInfo = {
        monthly_income : Nat;
        monthly_expenses : Nat;
        existing_debts : Nat;
        assets_value : Nat;
        bank_statements_provided : Bool;
        tax_returns_provided : Bool;
    };

    public type PropertyInfo = {
        submission_id : Text;
        estimated_value : Nat;
        property_type : Text; // "residential", "commercial", etc.
        location : Text;
        appraisal_date : ?Nat64;
        insurance_info : ?Text;
    };

    public type EventLog = {
        event_id : Nat;
        timestamp : Nat64;
        event_type : EventType;
        description : Text;
        related_loan_id : ?Text;
        actor_principal : ?Principal;
        amount : ?Nat;
    };

    public type EventType = {
        #loan_requested;
        #loan_approved;
        #loan_funded;
        #payment_made;
        #payment_missed;
        #loan_defaulted;
        #loan_repaid;
        #interest_rate_changed;
        #collateral_seized;
    };

    public type LoanResponse = {
        success : Bool;
        message : Text;
        loan_id : ?Text;
        monthly_payment : ?Nat;
        total_interest : ?Nat;
        approval_probability : ?Float; // 0.0 to 1.0
    };

    public type DashboardData = {
        borrower_data : ?{
            active_loans : Nat;
            total_borrowed : Nat;
            credit_score : Nat;
            payment_history_score : Nat;
            next_payment_due : ?{
                loan_id : Text;
                amount : Nat;
                due_date : Nat64;
            };
        };
        lender_data : ?{
            total_invested : Nat;
            active_investments : Nat;
            total_return : Nat;
            default_rate : Float;
            available_opportunities : Nat;
        };
        market_data : {
            average_interest_rate : Float;
            total_loans_funded : Nat;
            total_volume : Nat;
            default_rate : Float;
        };
    };

    public type LoanFilters = {
        status : ?LoanStatus;
        min_amount : ?Nat;
        max_amount : ?Nat;
        min_interest_rate : ?Float;
        max_interest_rate : ?Float;
        min_duration : ?Nat64;
        max_duration : ?Nat64;
        borrower : ?Principal;
        lender : ?Principal;
        property_type : ?Text;
        min_credit_score : ?Nat;
    };

    // Enhanced stable storage
    private stable var loans_entries : [(Text, LoanRequest)] = [];
    private stable var payments_entries : [(Text, PaymentRecord)] = [];
    private stable var lender_profiles_entries : [(Principal, LenderProfile)] = [];
    private stable var borrower_profiles_entries : [(Principal, BorrowerProfile)] = [];
    private stable var events_entries : [(Nat, EventLog)] = [];
    private stable var loan_counter : Nat = 0;
    private stable var payment_counter : Nat = 0;
    private stable var event_counter : Nat = 0;
    private stable var settings_entries : [(Text, Text)] = [];

    // Runtime storage
    private var loans = HashMap.HashMap<Text, LoanRequest>(50, Text.equal, Text.hash);
    private var payments = HashMap.HashMap<Text, PaymentRecord>(100, Text.equal, Text.hash);
    private var lender_profiles = HashMap.HashMap<Principal, LenderProfile>(20, Principal.equal, Principal.hash);
    private var borrower_profiles = HashMap.HashMap<Principal, BorrowerProfile>(50, Principal.equal, Principal.hash);
    private var events = HashMap.HashMap<Nat, EventLog>(200, Nat.equal, Hash.hash);
    private var settings = HashMap.HashMap<Text, Text>(10, Text.equal, Text.hash);

    // Constants and Configuration
    private let DEFAULT_INTEREST_RATE : Float = 0.08; // 8% annual interest
    private let MAX_LOAN_TO_VALUE_RATIO : Float = 0.75; // Max 75% of property value
    private let MIN_CREDIT_SCORE : Nat = 600; // Minimum credit score
    private let MAX_DEBT_TO_INCOME_RATIO : Float = 0.43; // Max 43% debt-to-income
    private let LATE_FEE_RATE : Float = 0.05; // 5% late fee
    private let SECONDS_PER_DAY : Nat64 = 86_400_000_000_000; // Nanoseconds in a day
    private let DAYS_BEFORE_DEFAULT : Nat64 = 90; // 90 days late = default

    // Helper functions
    private func logEvent(event_type : EventType, description : Text, loan_id : ?Text, actor_principal : ?Principal, amount : ?Nat) {
        let event : EventLog = {
            event_id = event_counter;
            timestamp = Nat64.fromIntWrap(Time.now());
            event_type = event_type;
            description = description;
            related_loan_id = loan_id;
            actor_principal = actor_principal;
            amount = amount;
        };
        events.put(event_counter, event);
        event_counter += 1;
    };

    private func calculateMonthlyPayment(principal : Nat, annual_rate : Float, months : Nat) : Nat {
        if (annual_rate == 0.0) {
            return principal / months;
        };
        let monthly_rate = annual_rate / 12.0;
        let months_float = Float.fromInt(months);
        let rate_plus_one = 1.0 + monthly_rate;
        let power_term = Float.pow(rate_plus_one, months_float);
        let numerator = Float.fromInt(principal) * monthly_rate * power_term;
        let denominator = power_term - 1.0;
        let monthly_payment = numerator / denominator;
        let monthly_payment_int = Float.toInt(Float.nearest(monthly_payment));
        if (monthly_payment_int > 0) {
            Nat64.toNat(Nat64.fromIntWrap(monthly_payment_int));
        } else {
            0;
        };
    };

    private func calculateTotalInterest(principal : Nat, monthly_payment : Nat, months : Nat) : Nat {
        let total_payments = monthly_payment * months;
        if (total_payments > principal) {
            total_payments - principal;
        } else {
            0;
        };
    };

    private func statusToText(status : LoanStatus) : Text {
        switch (status) {
            case (#pending) { "pending" };
            case (#under_review) { "under_review" };
            case (#approved) { "approved" };
            case (#funded) { "funded" };
            case (#repaying) { "repaying" };
            case (#repaid) { "repaid" };
            case (#defaulted) { "defaulted" };
            case (#foreclosed) { "foreclosed" };
            case (#rejected) { "rejected" };
        };
    };

    private func assessLoanRisk(application : LoanApplication, property_verification : PropertyInfo) : Float {
        var risk_score : Float = 0.0;

        // Credit score factor (40% weight)
        switch (borrower_profiles.get(application.borrower)) {
            case (?profile) {
                let credit_factor = Float.fromInt(profile.credit_score) / 850.0;
                risk_score += credit_factor * 0.4;
            };
            case null { risk_score += 0.2 }; // Default moderate score if no profile
        };

        // Debt-to-income ratio (30% weight)
        let dti = application.financial_info.existing_debts;
        let income = application.financial_info.monthly_income;
        if (income > 0) {
            let dti_ratio = Float.fromInt(dti) / Float.fromInt(income);
            let dti_factor = Float.max(0.0, 1.0 - (dti_ratio / MAX_DEBT_TO_INCOME_RATIO));
            risk_score += dti_factor * 0.3;
        };

        // Loan-to-value ratio (20% weight)
        let ltv_ratio = Float.fromInt(application.requested_amount) / Float.fromInt(property_verification.estimated_value);
        let ltv_factor = Float.max(0.0, 1.0 - (ltv_ratio / MAX_LOAN_TO_VALUE_RATIO));
        risk_score += ltv_factor * 0.2;

        // Employment verification (10% weight)
        if (application.employment_info.verified) {
            risk_score += 0.1;
        };

        Float.min(1.0, Float.max(0.0, risk_score));
    };

    // Initialize with enhanced demo data
    // private func initDemoData() {
    //     // Demo borrower profile
    //     let demo_borrower_profile : BorrowerProfile = {
    //         principal = Principal.fromText("3emtq-fq33w-tc3s5-qqcdi-rx6hb-aend7-s4wfw-57o35-t275p-blwia-tae");
    //         credit_score = 720;
    //         verified_income = ?500_000; // $5,000/month
    //         debt_to_income_ratio = 0.3;
    //         employment_status = "full-time";
    //         loan_history = ["L001"];
    //         payment_history_score = 85;
    //         properties_owned = ["S001"];
    //     };
    //     borrower_profiles.put(Principal.fromText("3emtq-fq33w-tc3s5-qqcdi-rx6hb-aend7-s4wfw-57o35-t275p-blwia-tae"), demo_borrower_profile);

    //     // Demo lender profile
    //     let demo_lender_profile : LenderProfile = {
    //         principal = Principal.fromText("3emtq-fq33w-tc3s5-qqcdi-rx6hb-aend7-s4wfw-57o35-t275p-blwia-tae");
    //         total_invested = 500_000_00; // $500,000
    //         active_loans = 5;
    //         completed_loans = 12;
    //         default_rate = 0.02; // 2%
    //         average_return = 0.085; // 8.5%
    //         reputation_score = 92;
    //         preferred_loan_types = ["residential", "commercial"];
    //         max_loan_amount = 250_000_00; // $250,000
    //         min_credit_score = 650;
    //     };
    //     lender_profiles.put(Principal.fromText("3emtq-fq33w-tc3s5-qqcdi-rx6hb-aend7-s4wfw-57o35-t275p-blwia-tae"), demo_lender_profile);

    //     // Demo loan
    //     let demo_loan : LoanRequest = {
    //         id = "L001";
    //         borrower = Principal.fromText("3emtq-fq33w-tc3s5-qqcdi-rx6hb-aend7-s4wfw-57o35-t275p-blwia-tae");
    //         submission_id = "S001";
    //         amount = 200_000_00; // $200,000
    //         duration = 360 * 30; // 30 years in days
    //         interest_rate = 0.075; // 7.5%
    //         timestamp = Nat64.fromIntWrap(Time.now());
    //         status = #funded;
    //         lender = ?Principal.fromText("3emtq-fq33w-tc3s5-qqcdi-rx6hb-aend7-s4wfw-57o35-t275p-blwia-tae");
    //         collateral_value = ?280_000_00; // $280,000
    //         monthly_payment = calculateMonthlyPayment(200_000_00, 0.075, 360);
    //         payments_made = 12;
    //         total_payments = 360;
    //         due_date = ?(Nat64.fromIntWrap(Time.now()) + (360 * 30 * SECONDS_PER_DAY));
    //         credit_score = ?720;
    //         loan_purpose = "Home purchase";
    //         employment_verification = true;
    //         income_verification = true;
    //         debt_to_income_ratio = ?0.3;
    //     };
    //     loans.put("L001", demo_loan);

    //     // Demo payment record
    //     let demo_payment : PaymentRecord = {
    //         payment_id = "P001";
    //         loan_id = "L001";
    //         amount = demo_loan.monthly_payment;
    //         payment_date = Nat64.fromIntWrap(Time.now() - (30 * Nat64.toNat(SECONDS_PER_DAY)));
    //         payment_type = #regular;
    //         late_fee = 0;
    //         principal_amount = 500_00; // $500
    //         interest_amount = demo_loan.monthly_payment - 500_00;
    //         remaining_balance = 199_500_00; // $199,500
    //     };
    //     payments.put("P001", demo_payment);

    //     // Settings
    //     settings.put("default_interest_rate", Float.toText(DEFAULT_INTEREST_RATE));
    //     settings.put("max_ltv_ratio", Float.toText(MAX_LOAN_TO_VALUE_RATIO));
    //     settings.put("min_credit_score", Nat.toText(MIN_CREDIT_SCORE));

    //     logEvent(#loan_funded, "Initialized demo loan L001", ?"L001", null, ?demo_loan.amount);
    //     loan_counter := 1;
    //     payment_counter := 1;
    // };

    // initDemoData();

    // Upgrade hooks
    system func preupgrade() {
        loans_entries := Iter.toArray(loans.entries());
        payments_entries := Iter.toArray(payments.entries());
        lender_profiles_entries := Iter.toArray(lender_profiles.entries());
        borrower_profiles_entries := Iter.toArray(borrower_profiles.entries());
        events_entries := Iter.toArray(events.entries());
        settings_entries := Iter.toArray(settings.entries());
    };

    system func postupgrade() {
        loans := HashMap.fromIter<Text, LoanRequest>(loans_entries.vals(), loans_entries.size(), Text.equal, Text.hash);
        payments := HashMap.fromIter<Text, PaymentRecord>(payments_entries.vals(), payments_entries.size(), Text.equal, Text.hash);
        lender_profiles := HashMap.fromIter<Principal, LenderProfile>(lender_profiles_entries.vals(), lender_profiles_entries.size(), Principal.equal, Principal.hash);
        borrower_profiles := HashMap.fromIter<Principal, BorrowerProfile>(borrower_profiles_entries.vals(), borrower_profiles_entries.size(), Principal.equal, Principal.hash);
        events := HashMap.fromIter<Nat, EventLog>(events_entries.vals(), events_entries.size(), Nat.equal, Hash.hash);
        settings := HashMap.fromIter<Text, Text>(settings_entries.vals(), settings_entries.size(), Text.equal, Text.hash);
        loans_entries := [];
        payments_entries := [];
        lender_profiles_entries := [];
        borrower_profiles_entries := [];
        events_entries := [];
        settings_entries := [];
    };

    // Submit a loan application
    public shared (msg) func submitLoanApplication(application : LoanApplication) : async LoanResponse {
        // Input validation
        if (application.requested_amount == 0) {
            return {
                success = false;
                message = "Loan amount must be greater than zero";
                loan_id = null;
                monthly_payment = null;
                total_interest = null;
                approval_probability = null;
            };
        };
        if (application.requested_amount < 1000_00) {
            // Minimum $1,000
            return {
                success = false;
                message = "Minimum loan amount is $1,000";
                loan_id = null;
                monthly_payment = null;
                total_interest = null;
                approval_probability = null;
            };
        };
        if (not Principal.equal(application.borrower, msg.caller)) {
            return {
                success = false;
                message = "Only the borrower can submit their loan application";
                loan_id = null;
                monthly_payment = null;
                total_interest = null;
                approval_probability = null;
            };
        };

        // Verify property with PropertyVerifier
        let submission = await PropertyVerifier.getSubmissionById(application.property_info.submission_id);
        switch (submission) {
            case null {
                return {
                    success = false;
                    message = "Property submission not found";
                    loan_id = null;
                    monthly_payment = null;
                    total_interest = null;
                    approval_probability = null;
                };
            };
            case (?sub) {
                if (sub.status != #verified) {
                    return {
                        success = false;
                        message = "Property must be verified";
                        loan_id = null;
                        monthly_payment = null;
                        total_interest = null;
                        approval_probability = null;
                    };
                };
                let verification = await PropertyVerifier.getVerificationResult(application.property_info.submission_id);
                switch (verification) {
                    case null {
                        return {
                            success = false;
                            message = "Property verification result not found";
                            loan_id = null;
                            monthly_payment = null;
                            total_interest = null;
                            approval_probability = null;
                        };
                    };
                    case (?ver) {
                        if (ver.verdict != #valid) {
                            return {
                                success = false;
                                message = "Property must have a valid verdict";
                                loan_id = null;
                                monthly_payment = null;
                                total_interest = null;
                                approval_probability = null;
                            };
                        };
                    };
                };
            };
        };

        // Check loan-to-value ratio
        let ltv_ratio = Float.fromInt(application.requested_amount) / Float.fromInt(application.property_info.estimated_value);
        if (ltv_ratio > MAX_LOAN_TO_VALUE_RATIO) {
            return {
                success = false;
                message = "Loan amount exceeds maximum loan-to-value ratio of " # Float.toText(MAX_LOAN_TO_VALUE_RATIO * 100.0) # "%";
                loan_id = null;
                monthly_payment = null;
                total_interest = null;
                approval_probability = null;
            };
        };

        // Validate borrower profile
        switch (borrower_profiles.get(msg.caller)) {
            case null {
                let new_profile : BorrowerProfile = {
                    principal = msg.caller;
                    credit_score = MIN_CREDIT_SCORE;
                    verified_income = ?application.financial_info.monthly_income;
                    debt_to_income_ratio = Float.fromInt(application.financial_info.existing_debts) / Float.fromInt(application.financial_info.monthly_income);
                    employment_status = application.employment_info.employment_type;
                    loan_history = [];
                    payment_history_score = 50; // Default
                    properties_owned = [application.property_info.submission_id];
                };
                borrower_profiles.put(msg.caller, new_profile);
            };
            case (?profile) {
                let updated_properties = Array.append(profile.properties_owned, [application.property_info.submission_id]);
                let updated_profile : BorrowerProfile = {
                    principal = profile.principal;
                    credit_score = profile.credit_score;
                    verified_income = ?application.financial_info.monthly_income;
                    debt_to_income_ratio = Float.fromInt(application.financial_info.existing_debts) / Float.fromInt(application.financial_info.monthly_income);
                    employment_status = application.employment_info.employment_type;
                    loan_history = profile.loan_history;
                    payment_history_score = profile.payment_history_score;
                    properties_owned = updated_properties;
                };
                borrower_profiles.put(msg.caller, updated_profile);
            };
        };

        // Calculate loan terms
        let months = Nat64.toNat(application.duration / 30); // Convert days to months
        let interest_rate = DEFAULT_INTEREST_RATE;
        let monthly_payment = calculateMonthlyPayment(application.requested_amount, interest_rate, months);
        let total_interest = calculateTotalInterest(application.requested_amount, monthly_payment, months);
        let approval_probability = assessLoanRisk(application, application.property_info);

        // Create loan request
        loan_counter += 1;
        let loan_id = "L" # Nat.toText(loan_counter);
        let loan : LoanRequest = {
            id = loan_id;
            borrower = msg.caller;
            submission_id = application.property_info.submission_id;
            amount = application.requested_amount;
            duration = application.duration;
            interest_rate = interest_rate;
            timestamp = Nat64.fromIntWrap(Time.now());
            status = if (approval_probability > 0.7) { #approved } else {
                #under_review;
            };
            lender = null;
            collateral_value = ?application.property_info.estimated_value;
            monthly_payment = monthly_payment;
            payments_made = 0;
            total_payments = months;
            due_date = ?(Nat64.fromIntWrap(Time.now()) + application.duration * SECONDS_PER_DAY);
            credit_score = switch (borrower_profiles.get(msg.caller)) {
                case (?profile) { ?profile.credit_score };
                case null { ?MIN_CREDIT_SCORE };
            };
            loan_purpose = application.loan_purpose;
            employment_verification = application.employment_info.verified;
            income_verification = application.financial_info.bank_statements_provided or application.financial_info.tax_returns_provided;
            debt_to_income_ratio = ?(Float.fromInt(application.financial_info.existing_debts) / Float.fromInt(application.financial_info.monthly_income));
        };
        loans.put(loan_id, loan);

        // Update borrower profile with loan history
        switch (borrower_profiles.get(msg.caller)) {
            case (?profile) {
                let updated_loan_history = Array.append(profile.loan_history, [loan_id]);
                let updated_profile : BorrowerProfile = {
                    principal = profile.principal;
                    credit_score = profile.credit_score;
                    verified_income = profile.verified_income;
                    debt_to_income_ratio = profile.debt_to_income_ratio;
                    employment_status = profile.employment_status;
                    loan_history = updated_loan_history;
                    payment_history_score = profile.payment_history_score;
                    properties_owned = profile.properties_owned;
                };
                borrower_profiles.put(msg.caller, updated_profile);
            };
            case null {};
        };

        logEvent(#loan_requested, "Loan application submitted: " # loan_id, ?loan_id, ?msg.caller, ?application.requested_amount);
        {
            success = true;
            message = "Loan application submitted successfully";
            loan_id = ?loan_id;
            monthly_payment = ?monthly_payment;
            total_interest = ?total_interest;
            approval_probability = ?approval_probability;
        };
    };

    // Fund a loan
    public shared (msg) func fundLoan(loan_id : Text) : async Result.Result<Text, Text> {
        switch (loans.get(loan_id)) {
            case null {
                return #err("Loan request not found");
            };
            case (?loan) {
                // Validate loan status
                let can_fund = switch (loan.status) {
                    case (#approved) { true };
                    case (#under_review) { true };
                    case (#pending) { true };
                    case (_) { false };
                };
                if (not can_fund) {
                    return #err("Loan is not available for funding (status: " # statusToText(loan.status) # ")");
                };
                if (Principal.equal(loan.borrower, msg.caller)) {
                    return #err("Borrower cannot fund their own loan");
                };

                // Check lender profile constraints
                switch (lender_profiles.get(msg.caller)) {
                    case (?profile) {
                        if (loan.amount > profile.max_loan_amount) {
                            return #err("Loan amount exceeds lender's maximum loan limit");
                        };
                        switch (loan.credit_score) {
                            case (?score) {
                                if (score < profile.min_credit_score) {
                                    return #err("Borrower's credit score is below lender's minimum requirement");
                                };
                            };
                            case null {
                                return #err("Borrower credit score not available");
                            };
                        };
                    };
                    case null {
                        let new_profile : LenderProfile = {
                            principal = msg.caller;
                            total_invested = 0;
                            active_loans = 0;
                            completed_loans = 0;
                            default_rate = 0.0;
                            average_return = 0.0;
                            reputation_score = 50;
                            preferred_loan_types = [];
                            max_loan_amount = 1_000_000_00; // $1M
                            min_credit_score = MIN_CREDIT_SCORE;
                        };
                        lender_profiles.put(msg.caller, new_profile);
                    };
                };

                // Update loan
                let updated_loan : LoanRequest = {
                    id = loan.id;
                    borrower = loan.borrower;
                    submission_id = loan.submission_id;
                    amount = loan.amount;
                    duration = loan.duration;
                    interest_rate = loan.interest_rate;
                    timestamp = loan.timestamp;
                    status = #funded;
                    lender = ?msg.caller;
                    collateral_value = loan.collateral_value;
                    monthly_payment = loan.monthly_payment;
                    payments_made = loan.payments_made;
                    total_payments = loan.total_payments;
                    due_date = loan.due_date;
                    credit_score = loan.credit_score;
                    loan_purpose = loan.loan_purpose;
                    employment_verification = loan.employment_verification;
                    income_verification = loan.income_verification;
                    debt_to_income_ratio = loan.debt_to_income_ratio;
                };
                loans.put(loan_id, updated_loan);

                // Update lender profile
                switch (lender_profiles.get(msg.caller)) {
                    case (?profile) {
                        let updated_profile : LenderProfile = {
                            principal = profile.principal;
                            total_invested = profile.total_invested + loan.amount;
                            active_loans = profile.active_loans + 1;
                            completed_loans = profile.completed_loans;
                            default_rate = profile.default_rate;
                            average_return = profile.average_return;
                            reputation_score = profile.reputation_score;
                            preferred_loan_types = profile.preferred_loan_types;
                            max_loan_amount = profile.max_loan_amount;
                            min_credit_score = profile.min_credit_score;
                        };
                        lender_profiles.put(msg.caller, updated_profile);
                    };
                    case null {};
                };

                logEvent(#loan_funded, "Loan funded by " # Principal.toText(msg.caller), ?loan_id, ?msg.caller, ?loan.amount);
                #ok("Loan funded successfully");
            };
        };
    };

    // Make a payment
    public shared (msg) func makePayment(loan_id : Text, amount : Nat, payment_type : PaymentType) : async Result.Result<PaymentRecord, Text> {
        switch (loans.get(loan_id)) {
            case null {
                return #err("Loan not found");
            };
            case (?loan) {
                if (not Principal.equal(loan.borrower, msg.caller)) {
                    return #err("Only the borrower can make payments on this loan");
                };
                let can_pay = switch (loan.status) {
                    case (#funded) { true };
                    case (#repaying) { true };
                    case (_) { false };
                };
                if (not can_pay) {
                    return #err("Loan is not in a payable status (current: " # statusToText(loan.status) # ")");
                };
                if (amount == 0) {
                    return #err("Payment amount must be greater than zero");
                };

                // Calculate remaining balance (simplified)
                let total_paid = loan.monthly_payment * loan.payments_made;
                let current_balance = if (total_paid < loan.amount) {
                    loan.amount - total_paid;
                } else { 0 };

                // Calculate interest and principal
                let monthly_rate = loan.interest_rate / 12.0;
                let interest_portion = Float.fromInt(current_balance) * monthly_rate;
                let principal_portion = if (amount > Float.toInt(interest_portion)) {
                    amount - Float.toInt(interest_portion);
                } else {
                    amount;
                };
                let new_balance = if (current_balance > principal_portion) {
                    current_balance - principal_portion;
                } else { 0 };

                // Check for late fees
                let now = Nat64.fromIntWrap(Time.now());
                let payment_due_date = loan.timestamp + (Nat64.fromNat(loan.payments_made + 1) * 30 * SECONDS_PER_DAY);
                let late_fee = if (now > payment_due_date + (7 * SECONDS_PER_DAY)) {
                    Float.toInt(Float.fromInt(loan.monthly_payment) * LATE_FEE_RATE);
                } else {
                    0;
                };

                // Create payment record
                payment_counter += 1;
                let payment_id = "P" # Nat.toText(payment_counter);
                let payment_record : PaymentRecord = {
                    payment_id = payment_id;
                    loan_id = loan_id;
                    amount = amount;
                    payment_date = now;
                    payment_type = payment_type;
                    late_fee = Nat64.toNat(Nat64.fromIntWrap(late_fee));
                    principal_amount = Nat64.toNat(Nat64.fromIntWrap(principal_portion));
                    interest_amount = Nat64.toNat(Nat64.fromIntWrap(Float.toInt(interest_portion)));
                    remaining_balance = Nat64.toNat(Nat64.fromIntWrap(new_balance));
                };
                payments.put(payment_id, payment_record);

                // Update loan
                let new_payments_made = loan.payments_made + 1;
                let new_status = if (new_payments_made >= loan.total_payments or new_balance == 0) {
                    #repaid;
                } else { #repaying };
                let updated_loan : LoanRequest = {
                    id = loan.id;
                    borrower = loan.borrower;
                    submission_id = loan.submission_id;
                    amount = loan.amount;
                    duration = loan.duration;
                    interest_rate = loan.interest_rate;
                    timestamp = loan.timestamp;
                    status = new_status;
                    lender = loan.lender;
                    collateral_value = loan.collateral_value;
                    monthly_payment = loan.monthly_payment;
                    payments_made = new_payments_made;
                    total_payments = loan.total_payments;
                    due_date = loan.due_date;
                    credit_score = loan.credit_score;
                    loan_purpose = loan.loan_purpose;
                    employment_verification = loan.employment_verification;
                    income_verification = loan.income_verification;
                    debt_to_income_ratio = loan.debt_to_income_ratio;
                };
                loans.put(loan_id, updated_loan);

                // Update borrower profile
                switch (borrower_profiles.get(msg.caller)) {
                    case (?profile) {
                        let payment_score = if (late_fee > 0) {
                            Nat.max(0, profile.payment_history_score - 5);
                        } else {
                            Nat.min(100, profile.payment_history_score + 2);
                        };
                        let updated_profile : BorrowerProfile = {
                            principal = profile.principal;
                            credit_score = profile.credit_score;
                            verified_income = profile.verified_income;
                            debt_to_income_ratio = profile.debt_to_income_ratio;
                            employment_status = profile.employment_status;
                            loan_history = profile.loan_history;
                            payment_history_score = payment_score;
                            properties_owned = profile.properties_owned;
                        };
                        borrower_profiles.put(msg.caller, updated_profile);
                    };
                    case null {};
                };

                // Update lender profile if repaid
                if (new_status == #repaid) {
                    switch (loan.lender) {
                        case (?lender_principal) {
                            switch (lender_profiles.get(lender_principal)) {
                                case (?profile) {
                                    let updated_profile : LenderProfile = {
                                        principal = profile.principal;
                                        total_invested = profile.total_invested;
                                        active_loans = if (profile.active_loans > 0) {
                                            profile.active_loans - 1;
                                        } else { 0 };
                                        completed_loans = profile.completed_loans + 1;
                                        default_rate = profile.default_rate;
                                        average_return = profile.average_return;
                                        reputation_score = Nat.min(100, profile.reputation_score + 2);
                                        preferred_loan_types = profile.preferred_loan_types;
                                        max_loan_amount = profile.max_loan_amount;
                                        min_credit_score = profile.min_credit_score;
                                    };
                                    lender_profiles.put(lender_principal, updated_profile);
                                };
                                case null {};
                            };
                        };
                        case null {};
                    };
                };

                logEvent(#payment_made, "Payment " # payment_id # " made for loan " # loan_id, ?loan_id, ?msg.caller, ?amount);
                #ok(payment_record);
            };
        };
    };

    // Mark loan as defaulted or foreclosed
    public shared (msg) func markLoanStatus(loan_id : Text, new_status : LoanStatus) : async Result.Result<Text, Text> {
        if (not Principal.equal(msg.caller, owner)) {
            return #err("Unauthorized: Only the canister owner can update loan status");
        };
        if (new_status != #defaulted and new_status != #foreclosed) {
            return #err("Invalid status: Can only mark as defaulted or foreclosed");
        };
        switch (loans.get(loan_id)) {
            case null {
                return #err("Loan not found");
            };
            case (?loan) {
                let can_update = switch (loan.status) {
                    case (#funded) { true };
                    case (#repaying) { true };
                    case (_) { false };
                };
                if (not can_update) {
                    return #err("Loan is not in a status that can be marked as defaulted or foreclosed");
                };
                let updated_loan : LoanRequest = {
                    id = loan.id;
                    borrower = loan.borrower;
                    submission_id = loan.submission_id;
                    amount = loan.amount;
                    duration = loan.duration;
                    interest_rate = loan.interest_rate;
                    timestamp = loan.timestamp;
                    status = new_status;
                    lender = loan.lender;
                    collateral_value = loan.collateral_value;
                    monthly_payment = loan.monthly_payment;
                    payments_made = loan.payments_made;
                    total_payments = loan.total_payments;
                    due_date = loan.due_date;
                    credit_score = loan.credit_score;
                    loan_purpose = loan.loan_purpose;
                    employment_verification = loan.employment_verification;
                    income_verification = loan.income_verification;
                    debt_to_income_ratio = loan.debt_to_income_ratio;
                };
                loans.put(loan_id, updated_loan);

                // Update lender profile
                switch (loan.lender) {
                    case (?lender_principal) {
                        switch (lender_profiles.get(lender_principal)) {
                            case (?profile) {
                                let total_loans = profile.active_loans + profile.completed_loans;
                                let new_default_rate = if (total_loans > 0) {
                                    (profile.default_rate * Float.fromInt(total_loans) + (if (new_status == #defaulted) { 1.0 } else { 0.0 })) / Float.fromInt(total_loans + 1);
                                } else {
                                    if (new_status == #defaulted) { 1.0 } else {
                                        0.0;
                                    };
                                };
                                let updated_profile : LenderProfile = {
                                    principal = profile.principal;
                                    total_invested = profile.total_invested;
                                    active_loans = if (profile.active_loans > 0) {
                                        profile.active_loans - 1;
                                    } else { 0 };
                                    completed_loans = profile.completed_loans + 1;
                                    default_rate = new_default_rate;
                                    average_return = profile.average_return;
                                    reputation_score = Nat.max(0, profile.reputation_score - 5);
                                    preferred_loan_types = profile.preferred_loan_types;
                                    max_loan_amount = profile.max_loan_amount;
                                    min_credit_score = profile.min_credit_score;
                                };
                                lender_profiles.put(lender_principal, updated_profile);
                            };
                            case null {};
                        };
                    };
                    case null {};
                };

                // Update borrower profile
                switch (borrower_profiles.get(loan.borrower)) {
                    case (?profile) {
                        let updated_profile : BorrowerProfile = {
                            principal = profile.principal;
                            credit_score = Nat.max(0, profile.credit_score - 50);
                            verified_income = profile.verified_income;
                            debt_to_income_ratio = profile.debt_to_income_ratio;
                            employment_status = profile.employment_status;
                            loan_history = profile.loan_history;
                            payment_history_score = Nat.max(0, profile.payment_history_score - 10);
                            properties_owned = profile.properties_owned;
                        };
                        borrower_profiles.put(loan.borrower, updated_profile);
                    };
                    case null {};
                };

                let event_type = if (new_status == #defaulted) {
                    #loan_defaulted;
                } else { #collateral_seized };
                logEvent(event_type, "Loan " # loan_id # " marked as " # statusToText(new_status), ?loan_id, ?msg.caller, null);
                #ok("Loan status updated to " # statusToText(new_status));
            };
        };
    };

    // Query functions
    // public shared func getAllLoans(filters: ?LoanFilters) : async [LoanRequest] {
    //     let all_loans = Array.map<(Text, LoanRequest), LoanRequest>(
    //         Iter.toArray(loans.entries()),
    //         func((id, loan)) = loan
    //     );
    //     async switch (filters) {
    //         case null { all_loans };
    //         case (?f) {
    //             Array.filter<LoanRequest>(all_loans, async func(loan) {
    //                 let status_match = switch (f.status) {
    //                     case (?s) { loan.status == s };
    //                     case null { true };
    //                 };
    //                 let min_amount_match = switch (f.min_amount) {
    //                     case (?m) { loan.amount >= m };
    //                     case null { true };
    //                 };
    //                 let max_amount_match = switch (f.max_amount) {
    //                     case (?m) { loan.amount <= m };
    //                     case null { true };
    //                 };
    //                 let min_rate_match = switch (f.min_interest_rate) {
    //                     case (?r) { loan.interest_rate >= r };
    //                     case null { true };
    //                 };
    //                 let max_rate_match = switch (f.max_interest_rate) {
    //                     case (?r) { loan.interest_rate <= r };
    //                     case null { true };
    //                 };
    //                 let min_duration_match = switch (f.min_duration) {
    //                     case (?d) { loan.duration >= d };
    //                     case null { true };
    //                 };
    //                 let max_duration_match = switch (f.max_duration) {
    //                     case (?d) { loan.duration <= d };
    //                     case null { true };
    //                 };
    //                 let borrower_match = switch (f.borrower) {
    //                     case (?b) { Principal.equal(loan.borrower, b) };
    //                     case null { true };
    //                 };
    //                 let lender_match = switch (f.lender) {
    //                     case (?l) { Option.isSome(loan.lender) and Principal.equal(Option.get(loan.lender, Principal.fromText("aaaaa-aa")), l) };
    //                     case null { true };
    //                 };
    //                 let credit_score_match = switch (f.min_credit_score) {
    //                     case (?cs) { Option.isSome(loan.credit_score) and Option.get(loan.credit_score, 0) >= cs };
    //                     case null { true };
    //                 };
    //                 let property_type_match = async switch (f.property_type) {
    //                     case (?pt) {
    //                         let submission = await PropertyVerifier.getSubmissionById(loan.submission_id) ;
    //                         async switch (await submission()) {
    //                             case (?sub) {
    //                                 let verification = await PropertyVerifier.getVerificationResult(loan.submission_id);
    //                                 switch (await verification()) {
    //                                     case (?ver) { ver.location == pt }; // Simplified, adjust based on actual property type
    //                                     case null { false };
    //                                 };
    //                             };
    //                             case null { false };
    //                         };
    //                     };
    //                     case null { true };
    //                 };
    //                 status_match and min_amount_match and max_amount_match and min_rate_match and max_rate_match and
    //                 min_duration_match and max_duration_match and borrower_match and lender_match and credit_score_match and property_type_match
    //             });
    //         };
    //     }
    // };

    public shared func getAllLoans2(filters : ?LoanFilters) : async [LoanRequest] {
        let all_loans = Array.map<(Text, LoanRequest), LoanRequest>(
            Iter.toArray(loans.entries()),
            func((id, loan)) = loan,
        );
        switch (filters) {
            case null { all_loans };
            case (?f) {
                var filtered : [LoanRequest] = [];
                for (loan in all_loans.vals()) {
                    // Synchronous checks
                    let status_match = switch (f.status) {
                        case (?s) { loan.status == s };
                        case null { true };
                    };
                    let min_amount_match = switch (f.min_amount) {
                        case (?m) { loan.amount >= m };
                        case null { true };
                    };
                    let max_amount_match = switch (f.max_amount) {
                        case (?m) { loan.amount <= m };
                        case null { true };
                    };
                    let min_rate_match = switch (f.min_interest_rate) {
                        case (?r) { loan.interest_rate >= r };
                        case null { true };
                    };
                    let max_rate_match = switch (f.max_interest_rate) {
                        case (?r) { loan.interest_rate <= r };
                        case null { true };
                    };
                    let min_duration_match = switch (f.min_duration) {
                        case (?d) { loan.duration >= d };
                        case null { true };
                    };
                    let max_duration_match = switch (f.max_duration) {
                        case (?d) { loan.duration <= d };
                        case null { true };
                    };
                    let borrower_match = switch (f.borrower) {
                        case (?b) { Principal.equal(loan.borrower, b) };
                        case null { true };
                    };
                    let lender_match = switch (f.lender) {
                        case (?l) {
                            Option.isSome(loan.lender) and Principal.equal(Option.get(loan.lender, Principal.fromText("aaaaa-aa")), l)
                        };
                        case null { true };
                    };
                    let credit_score_match = switch (f.min_credit_score) {
                        case (?cs) {
                            Option.isSome(loan.credit_score) and Option.get(loan.credit_score, 0) >= cs
                        };
                        case null { true };
                    };
                    // ... other synchronous checks ...

                    // Asynchronous check
                    var property_type_match = true;
                    switch (f.property_type) {
                        case (?pt) {
                            let submission = await PropertyVerifier.getSubmissionById(loan.submission_id);
                            switch (submission) {
                                case (?sub) {
                                    let verification = await PropertyVerifier.getVerificationResult(loan.submission_id);
                                    switch (verification) {
                                        case (?ver) {
                                            property_type_match := ver.location == pt;
                                        };
                                        case null {
                                            property_type_match := false;
                                        };
                                    };
                                };
                                case null { property_type_match := false };
                            };
                        };
                        case null { property_type_match := true };
                    };

                    if (
                        status_match and min_amount_match and max_amount_match and min_rate_match and max_rate_match and
                        min_duration_match and max_duration_match and borrower_match and lender_match and credit_score_match and property_type_match
                    ) {
                        filtered := Array.append(filtered, [loan]);
                    };
                };
                filtered;
            };
        };
    };

    public query func getLoanById(loan_id : Text) : async ?LoanRequest {
        loans.get(loan_id);
    };

    public query func getPaymentsByLoan(loan_id : Text) : async [PaymentRecord] {
        Array.filter<PaymentRecord>(
            Array.map<(Text, PaymentRecord), PaymentRecord>(
                Iter.toArray(payments.entries()),
                func((id, payment)) = payment,
            ),
            func(payment) = payment.loan_id == loan_id,
        );
    };

    public query func getDashboardData(principal : Principal) : async DashboardData {
        let borrower_loans = Array.filter<LoanRequest>(
            Array.map<(Text, LoanRequest), LoanRequest>(
                Iter.toArray(loans.entries()),
                func((id, loan)) = loan,
            ),
            func(loan) = Principal.equal(loan.borrower, principal) and (loan.status == #funded or loan.status == #repaying),
        );
        let lender_loans = Array.filter<LoanRequest>(
            Array.map<(Text, LoanRequest), LoanRequest>(
                Iter.toArray(loans.entries()),
                func((id, loan)) = loan,
            ),
            func(loan) = Option.isSome(loan.lender) and Principal.equal(Option.get(loan.lender, Principal.fromText("aaaaa-aa")), principal),
        );
        let available_loans = Array.filter<LoanRequest>(
            Array.map<(Text, LoanRequest), LoanRequest>(
                Iter.toArray(loans.entries()),
                func((id, loan)) = loan,
            ),
            func(loan) = loan.status == #approved or loan.status == #under_review,
        );

        let borrower_data = if (borrower_loans.size() > 0 or borrower_profiles.get(principal) != null) {
            let profile = Option.get(
                borrower_profiles.get(principal),
                {
                    principal = principal;
                    credit_score = MIN_CREDIT_SCORE;
                    verified_income = null;
                    debt_to_income_ratio = 0.0;
                    employment_status = "";
                    loan_history = [];
                    payment_history_score = 50;
                    properties_owned = [];
                },
            );
            let total_borrowed = Array.foldLeft<LoanRequest, Nat>(borrower_loans, 0, func(sum, loan) = sum + loan.amount);
            let next_payment = Array.find<LoanRequest>(borrower_loans, func(loan) = loan.payments_made < loan.total_payments);
            ?{
                active_loans = borrower_loans.size();
                total_borrowed = total_borrowed;
                credit_score = profile.credit_score;
                payment_history_score = profile.payment_history_score;
                next_payment_due = Option.map<LoanRequest, { loan_id : Text; amount : Nat; due_date : Nat64 }>(
                next_payment,
                func(loan : LoanRequest) = {
                    loan_id = loan.id;
                    amount = loan.monthly_payment;
                    due_date = loan.timestamp + (Nat64.fromNat(loan.payments_made + 1) * 30 * SECONDS_PER_DAY);
                }
                );};
        } else {
            null;
        };

        let lender_data = if (lender_loans.size() > 0 or lender_profiles.get(principal) != null) {
            let profile = Option.get(
                lender_profiles.get(principal),
                {
                    principal = principal;
                    total_invested = 0;
                    active_loans = 0;
                    completed_loans = 0;
                    default_rate = 0.0;
                    average_return = 0.0;
                    reputation_score = 50;
                    preferred_loan_types = [];
                    max_loan_amount = 1_000_000_00;
                    min_credit_score = MIN_CREDIT_SCORE;
                },
            );
            let total_return = Array.foldLeft<LoanRequest, Nat>(lender_loans, 0, func(sum, loan) = sum + calculateTotalInterest(loan.amount, loan.monthly_payment, loan.total_payments));
            ?{
                total_invested = profile.total_invested;
                active_investments = profile.active_loans;
                total_return = total_return;
                default_rate = profile.default_rate;
                available_opportunities = available_loans.size();
            };
        } else {
            null;
        };

        let market_loans = Array.map<(Text, LoanRequest), LoanRequest>(
            Iter.toArray(loans.entries()),
            func((id, loan)) = loan,
        );
        let total_volume = Array.foldLeft<LoanRequest, Nat>(market_loans, 0, func(sum, loan) = sum + loan.amount);
        let funded_loans = Array.filter<LoanRequest>(market_loans, func(loan) = loan.status == #funded or loan.status == #repaying or loan.status == #repaid);
        let defaulted_loans = Array.filter<LoanRequest>(market_loans, func(loan) = loan.status == #defaulted);
        let average_rate = if (market_loans.size() > 0) {
            Array.foldLeft<LoanRequest, Float>(market_loans, 0.0, func(sum, loan) = sum + loan.interest_rate) / Float.fromInt(market_loans.size());
        } else {
            0.0;
        };
        let default_rate = if (market_loans.size() > 0) {
            Float.fromInt(defaulted_loans.size()) / Float.fromInt(market_loans.size());
        } else {
            0.0;
        };

        {
            borrower_data = borrower_data;
            lender_data = lender_data;
            market_data = {
                average_interest_rate = average_rate;
                total_loans_funded = funded_loans.size();
                total_volume = total_volume;
                default_rate = default_rate;
            };
        };
    };

    public query func getEventLogs() : async [EventLog] {
        Array.map<(Nat, EventLog), EventLog>(
            Iter.toArray(events.entries()),
            func((id, event)) = event,
        );
    };

    public query func getBorrowerProfile(principal : Principal) : async ?BorrowerProfile {
        borrower_profiles.get(principal);
    };

    public query func getLenderProfile(principal : Principal) : async ?LenderProfile {
        lender_profiles.get(principal);
    };

    // Admin function to update settings
    public shared (msg) func updateSettings(key : Text, value : Text) : async Result.Result<Text, Text> {
        if (not Principal.equal(msg.caller, owner)) {
            return #err("Unauthorized: Only the canister owner can update settings");
        };
        settings.put(key, value);
        logEvent(#interest_rate_changed, "Setting updated: " # key # " = " # value, null, ?msg.caller, null);
        #ok("Setting updated successfully");
    };
};
