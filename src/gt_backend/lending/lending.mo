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
import RwaVerifier "canister:rwa_verifier";
import Rwa "canister:rwa";

shared(msg) actor class LendingBorrowing() = this {
    // Configuration
    private let owner : Principal = msg.caller; // Replace with actual owner principal

    // Enhanced Types
    public type LoanRequest = {
        id : Text;
        borrower : Principal;
        submission_id : Text; // RWA submission ID from RwaVerifier
        amount : Nat; // Loan amount in USD cents
        duration : Nat64; // Loan duration in days
        interest_rate : Float; // Annual interest rate
        timestamp : Nat64;
        status : LoanStatus;
        lender : ?Principal;
        collateral_value : ?Nat; // Estimated RWA value in USD cents
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
        rwa_owned : [Text]; // Array of RWA submission IDs
    };

    public type LoanApplication = {
        borrower : Principal;
        requested_amount : Nat;
        loan_purpose : Text;
        employment_info : EmploymentInfo;
        financial_info : FinancialInfo;
        rwa_info : RwaInfo;
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

    public type RwaInfo = {
        submission_id : Text;
        estimated_value : Nat;
        rwa_type : Text; // "residential", "commercial", etc.
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
        rwa_type : ?Text;
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
    private let MAX_LOAN_TO_VALUE_RATIO : Float = 0.75; // Max 75% of RWA value
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

    private func assessLoanRisk(application : LoanApplication, rwa_verification : RwaInfo) : Float {
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
        let ltv_ratio = Float.fromInt(application.requested_amount) / Float.fromInt(rwa_verification.estimated_value);
        let ltv_factor = Float.max(0.0, 1.0 - (ltv_ratio / MAX_LOAN_TO_VALUE_RATIO));
        risk_score += ltv_factor * 0.2;

        // Employment verification (10% weight)
        if (application.employment_info.verified) {
            risk_score += 0.1;
        };

        Float.min(1.0, Float.max(0.0, risk_score));
    };

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

        // Verify RWA with RwaVerifier
        let submission = await RwaVerifier.getSubmissionById(application.rwa_info.submission_id);
        switch (submission) {
            case null {
                return {
                    success = false;
                    message = "RWA submission not found";
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
                        message = "RWA must be verified";
                        loan_id = null;
                        monthly_payment = null;
                        total_interest = null;
                        approval_probability = null;
                    };
                };
                let verification = await RwaVerifier.getVerificationResult(application.rwa_info.submission_id);
                switch (verification) {
                    case null {
                        return {
                            success = false;
                            message = "RWA verification result not found";
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
                                message = "RWA must have a valid verdict";
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
        let ltv_ratio = Float.fromInt(application.requested_amount) / Float.fromInt(application.rwa_info.estimated_value);
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
                    rwa_owned = [application.rwa_info.submission_id];
                };
                borrower_profiles.put(msg.caller, new_profile);
            };
            case (?profile) {
                let updated_rwas = Array.append(profile.rwa_owned, [application.rwa_info.submission_id]);
                let updated_profile : BorrowerProfile = {
                    principal = profile.principal;
                    credit_score = profile.credit_score;
                    verified_income = ?application.financial_info.monthly_income;
                    debt_to_income_ratio = Float.fromInt(application.financial_info.existing_debts) / Float.fromInt(application.financial_info.monthly_income);
                    employment_status = application.employment_info.employment_type;
                    loan_history = profile.loan_history;
                    payment_history_score = profile.payment_history_score;
                    rwa_owned = updated_rwas;
                };
                borrower_profiles.put(msg.caller, updated_profile);
            };
        };

        // Calculate loan terms
        let months = Nat64.toNat(application.duration / 30); // Convert days to months
        let interest_rate = DEFAULT_INTEREST_RATE;
        let monthly_payment = calculateMonthlyPayment(application.requested_amount, interest_rate, months);
        let total_interest = calculateTotalInterest(application.requested_amount, monthly_payment, months);
        let approval_probability = assessLoanRisk(application, application.rwa_info);

        // Create loan request
        loan_counter += 1;
        let loan_id = "L" # Nat.toText(loan_counter);
        let loan : LoanRequest = {
            id = loan_id;
            borrower = msg.caller;
            submission_id = application.rwa_info.submission_id;
            amount = application.requested_amount;
            duration = application.duration;
            interest_rate = interest_rate;
            timestamp = Nat64.fromIntWrap(Time.now());
            status = if (approval_probability > 0.7) { #approved } else {
                #under_review;
            };
            lender = null;
            collateral_value = ?application.rwa_info.estimated_value;
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
                    rwa_owned = profile.rwa_owned;
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

    // ... rest of the file is the same
};
