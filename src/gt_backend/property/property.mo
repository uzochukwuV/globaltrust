import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Char "mo:base/Char";
import Hash "mo:base/Hash";
import Float "mo:base/Float";

actor PropertyVerifier {
    // Configuration
    private let owner: Principal = Principal.fromText("aaaaa-aa"); // Replace with actual owner principal
    private let DEEPSEEK_API_URL = "https://api.novita.ai/v3/openai/chat/completions";
    private let API_KEY = "your-deepseek-api-key"; // TODO: Replace with actual API key

    // Enhanced Types for better UX
    public type PropertySubmission = {
        id: Text;
        submitter: Principal;
        document_title: Text;
        document_text: Text;
        ipfs_hash: ?Text;
        timestamp: Nat64;
        status: SubmissionStatus;
        file_type: ?Text; // PDF, DOCX, etc.
        file_size: ?Nat; // in bytes
        submission_notes: ?Text; // User can add notes
    };

    public type SubmissionStatus = {
        #pending;
        #ai_verifying;
        #ai_verified;
        #ai_rejected;
        #admin_reviewing;
        #verified;
        #rejected;
        #requires_human_review;
    };

    public type AIVerificationResult = {
        submission_id: Text;
        owner: Text;
        location: Text;
        issue_date: Text;
        confidence_score: Nat;
        verdict: VerificationVerdict;
        ai_response: Text;
        verification_timestamp: Nat64;
        red_flags: [Text]; // Array of specific issues found
        extracted_fields: [(Text, Text)]; // Key-value pairs of extracted data
    };

    public type VerificationVerdict = {
        #valid;
        #suspicious;
        #invalid;
        #requires_review; // New status for edge cases
    };

    public type EventLog = {
        event_id: Nat;
        timestamp: Nat64;
        event_type: EventType;
        description: Text;
        related_submission_id: ?Text;
        actor_principal: ?Principal;
    };

    public type EventType = {
        #submission_created;
        #ai_verification_started;
        #ai_verification_completed;
        #admin_review;
        #status_changed;
        #error_occurred;
    };

    // UI-friendly response types
    public type SubmissionResponse = {
        success: Bool;
        message: Text;
        submission_id: ?Text;
        estimated_processing_time: ?Nat; // in seconds
    };

    public type DashboardData = {
        total_submissions: Nat;
        pending_submissions: Nat;
        verified_submissions: Nat;
        rejected_submissions: Nat;
        recent_submissions: [PropertySubmission];
        recent_events: [EventLog];
        user_submissions: [PropertySubmission]; // For current user
    };

    public type SubmissionFilters = {
        status: ?SubmissionStatus;
        submitter: ?Principal;
        date_from: ?Nat64;
        date_to: ?Nat64;
        confidence_min: ?Nat;
        confidence_max: ?Nat;
    };

    // HTTP types (same as before)
    public type HttpRequestArgs = {
        url: Text;
        max_response_bytes: ?Nat64;
        headers: [HttpHeader];
        body: ?[Nat8];
        method: HttpMethod;
        transform: ?TransformRawResponseFunction;
    };

    public type HttpHeader = { name: Text; value: Text; };
    public type HttpMethod = { #get; #post; #head; };
    public type HttpResponsePayload = { status: Nat; headers: [HttpHeader]; body: [Nat8]; };
    public type TransformRawResponseFunction = {
        function: shared query TransformRawResponse -> async HttpResponsePayload;
        context: Blob;
    };
    public type TransformRawResponse = { status: Nat; body: [Nat8]; headers: [HttpHeader]; context: Blob; };

    private let management_canister: actor { http_request: HttpRequestArgs -> async HttpResponsePayload } = actor("aaaaa-aa");

    // Enhanced stable storage
    private stable var submissions_entries: [(Text, PropertySubmission)] = [];
    private stable var verifications_entries: [(Text, AIVerificationResult)] = [];
    private stable var events_entries: [(Nat, EventLog)] = [];
    private stable var submission_counter: Nat = 0;
    private stable var event_counter: Nat = 0;
    private stable var settings_entries: [(Text, Text)] = []; // For canister settings

    // Runtime storage
    private var submissions = HashMap.HashMap<Text, PropertySubmission>(10, Text.equal, Text.hash);
    private var verifications = HashMap.HashMap<Text, AIVerificationResult>(10, Text.equal, Text.hash);
    private var events = HashMap.HashMap<Nat, EventLog>(10, Nat.equal, Hash.hash);
    private var settings = HashMap.HashMap<Text, Text>(10, Text.equal, Text.hash);

    // Helper functions
    private func textToBytes(text: Text) : [Nat8] {
        Blob.toArray(Text.encodeUtf8(text))
    };

    private func bytesToText(bytes: [Nat8]) : Text {
        switch (Text.decodeUtf8(Blob.fromArray(bytes))) {
            case (?text) { text };
            case null { "" };
        }
    };

    private func logEvent(event_type: EventType, description: Text, submission_id: ?Text, actor_principal: ?Principal) {
        let event: EventLog = {
            event_id = event_counter;
            timestamp = Nat64.fromIntWrap(Time.now());
            event_type = event_type;
            description = description;
            related_submission_id = submission_id;
            actor_principal = actor_principal;
        };
        events.put(event_counter, event);
        event_counter += 1;
    };

    private func updateSubmissionStatus(submission_id: Text, new_status: SubmissionStatus) : Result.Result<(), Text> {
        switch (submissions.get(submission_id)) {
            case null { #err("Submission not found") };
            case (?submission) {
                let updated_submission: PropertySubmission = {
                    id = submission.id;
                    submitter = submission.submitter;
                    document_title = submission.document_title;
                    document_text = submission.document_text;
                    ipfs_hash = submission.ipfs_hash;
                    timestamp = submission.timestamp;
                    status = new_status;
                    file_type = submission.file_type;
                    file_size = submission.file_size;
                    submission_notes = submission.submission_notes;
                };
                submissions.put(submission_id, updated_submission);
                logEvent(#status_changed, "Status changed to " # statusToText(new_status), ?submission_id, null);
                #ok(())
            };
        }
    };

    private func statusToText(status: SubmissionStatus) : Text {
        switch (status) {
            case (#pending) { "pending" };
            case (#ai_verifying) { "ai_verifying" };
            case (#ai_verified) { "ai_verified" };
            case (#ai_rejected) { "ai_rejected" };
            case (#admin_reviewing) { "admin_reviewing" };
            case (#verified) { "verified" };
            case (#rejected) { "rejected" };
            case (#requires_human_review) { "requires_human_review" };
        }
    };

    private func verdictToText(verdict: VerificationVerdict) : Text {
        switch (verdict) {
            case (#valid) { "valid" };
            case (#suspicious) { "suspicious" };
            case (#invalid) { "invalid" };
            case (#requires_review) { "requires_review" };
        }
    };

    // Initialize with better demo data
    private func initDemoData() {
        let demo_submission1: PropertySubmission = {
            id = "S001";
            submitter = Principal.fromText("2vxsx-fae");
            document_title = "Title Deed - 123 Main St";
            document_text = "PROPERTY DEED\n\nProperty Address: 123 Main Street, Downtown, NY 10001\nOwner: John Doe\nIssue Date: January 15, 2020\nRegistration Number: NYC-2020-001234\nProperty Type: Residential\nLot Size: 0.25 acres\nBuilding Area: 2,500 sq ft\n\nThis document certifies the ownership of the above-mentioned property...";
            ipfs_hash = ?"QmbFMke1KXqnYy1Y8u1t1t1t1t1t1t1t1t1t1t1t1t1t1t";
            timestamp = Nat64.fromIntWrap(Time.now());
            status = #ai_verified;
            file_type = ?"PDF";
            file_size = ?245678;
            submission_notes = ?"Original property deed from city hall";
        };

        let demo_submission2: PropertySubmission = {
            id = "S002";
            submitter = Principal.fromText("2vxsx-fae");
            document_title = "Title Deed - 456 Oak Ave";
            document_text = "Property at 456 Oak Ave, owned by Jane Smith, issued on 2019-06-20. This property is located in the residential district...";
            ipfs_hash = null;
            timestamp = Nat64.fromIntWrap(Time.now() + 3600_000_000_000); // 1 hour ago
            status = #pending;
            file_type = ?"DOCX";
            file_size = ?123456;
            submission_notes = null;
        };

        submissions.put("S001", demo_submission1);
        submissions.put("S002", demo_submission2);
        
        // Add demo verification result
        let demo_verification: AIVerificationResult = {
            submission_id = "S001";
            owner = "John Doe";
            location = "123 Main Street, Downtown, NY 10001";
            issue_date = "January 15, 2020";
            confidence_score = 92;
            verdict = #valid;
            ai_response = "{\"is_authentic\": true, \"owner\": \"John Doe\", \"location\": \"123 Main Street, Downtown, NY 10001\", \"issue_date\": \"January 15, 2020\", \"confidence_score\": 92, \"verdict\": \"valid\"}";
            verification_timestamp = Nat64.fromIntWrap(Time.now());
            red_flags = [];
            extracted_fields = [("Registration Number", "NYC-2020-001234"), ("Property Type", "Residential"), ("Lot Size", "0.25 acres")];
        };
        verifications.put("S001", demo_verification);

        logEvent(#submission_created, "Initialized demo data with 2 submissions", null, null);
        submission_counter := 2;
    };

    initDemoData();

    // // Upgrade hooks
    // system func preupgrade() {
    //     submissions_entries := Iter.toArray(submissions.entries());
    //     verifications_entries := Iter.toArray(verifications.entries());
    //     events_entries := Iter.toArray(events.entries());
    //     settings_entries := Iter.toArray(settings.entries());
    // };

    // system func postupgrade() {
    //     submissions := HashMap.fromIter<Text, PropertySubmission>(submissions_entries.vals(), submissions_entries.size(), Text.equal, Text.hash);
    //     verifications := HashMap.fromIter<Text, AIVerificationResult>(verifications_entries.vals(), verifications_entries.size(), Text.equal, Text.hash);
    //     events := HashMap.fromIter<Nat, EventLog>(events_entries.vals(), events_entries.size(), Nat.equal, Nat.hash);
    //     settings := HashMap.fromIter<Text, Text>(settings_entries.vals(), settings_entries.size(), Text.equal, Text.hash);
    //     submissions_entries := [];
    //     verifications_entries := [];
    //     events_entries := [];
    //     settings_entries := [];
    // };

    // Enhanced submission function with better UX
    public shared(msg) func submitPropertyDocument(
        document_title: Text,
        document_text: Text,
        ipfs_hash: ?Text,
        file_type: ?Text,
        file_size: ?Nat,
        submission_notes: ?Text
    ) : async SubmissionResponse {
        
        // Input validation
        if (Text.size(document_title) == 0) {
            return {
                success = false;
                message = "Document title cannot be empty";
                submission_id = null;
                estimated_processing_time = null;
            };
        };

        if (Text.size(document_text) < 50) {
            return {
                success = false;
                message = "Document text is too short (minimum 50 characters)";
                submission_id = null;
                estimated_processing_time = null;
            };
        };

        submission_counter += 1;
        let submission_id = "S" # Nat.toText(submission_counter);
        
        let submission: PropertySubmission = {
            id = submission_id;
            submitter = msg.caller;
            document_title = document_title;
            document_text = document_text;
            ipfs_hash = ipfs_hash;
            timestamp = Nat64.fromIntWrap(Time.now());
            status = #ai_verifying;
            file_type = file_type;
            file_size = file_size;
            submission_notes = submission_notes;
        };

        submissions.put(submission_id, submission);
        logEvent(#submission_created, "New submission created", ?submission_id, ?msg.caller);

        // Start AI verification asynchronously
        let verification_result = await verifyDocument(submission_id, document_text);
        switch (verification_result) {
            case (#ok(result)) {
                verifications.put(submission_id, result);
                let new_status = switch (result.verdict) {
                    case (#valid) { #ai_verified };
                    case (#suspicious) { #requires_human_review };
                    case (#invalid) { #ai_rejected };
                    case (#requires_review) { #requires_human_review };
                };
                ignore updateSubmissionStatus(submission_id, new_status);
                logEvent(#ai_verification_completed, "AI verification completed: " # verdictToText(result.verdict), ?submission_id, null);
                
                {
                    success = true;
                    message = "Document submitted successfully and AI verification completed";
                    submission_id = ?submission_id;
                    estimated_processing_time = ?30; // 30 seconds for admin review if needed
                }
            };
            case (#err(error)) {
                ignore updateSubmissionStatus(submission_id, #requires_human_review);
                logEvent(#error_occurred, "AI verification failed: " # error, ?submission_id, null);
                
                {
                    success = true;
                    message = "Document submitted successfully, but AI verification failed. Manual review required.";
                    submission_id = ?submission_id;
                    estimated_processing_time = ?300; // 5 minutes for manual review
                }
            };
        }
    };

    // Enhanced AI verification with better parsing
    private func verifyDocument(submission_id: Text, document_text: Text) : async Result.Result<AIVerificationResult, Text> {
        logEvent(#ai_verification_started, "Starting AI verification", ?submission_id, null);
        
        let enhanced_prompt = "You are an expert property document verification AI. Analyze the following property document for authenticity and extract key information.\n\n" #
            "Document to analyze:\n" # document_text # "\n\n" #
            "Please provide a detailed analysis and return a JSON object with the following fields:\n" #
            "- is_authentic: boolean (true if document appears genuine)\n" #
            "- owner: string (property owner name)\n" #
            "- location: string (full property address)\n" #
            "- issue_date: string (document issue date)\n" #
            "- red_flags: array of strings (specific issues found)\n" #
            "- confidence_score: float (0 to 100)\n" #
            "- verdict: string ('valid', 'suspicious', 'invalid', or 'requires_review')\n" #
            "- extracted_fields: object with additional key-value pairs found in the document";

        let requestBody = "{\"model\":\"deepseek/deepseek-r1-0528\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a property document verification AI. Provide accurate and reliable analysis in JSON format.\"},{\"role\":\"user\",\"content\":\"" # enhanced_prompt # "\"}],\"max_tokens\":800,\"temperature\":0.1}";
        let requestBodyBytes = textToBytes(requestBody);

        let httpRequest: HttpRequestArgs = {
            url = DEEPSEEK_API_URL;
            max_response_bytes = ?8192;
            headers = [
                { name = "Content-Type"; value = "application/json" },
                { name = "Authorization"; value = "Bearer " # API_KEY }
            ];
            body = ?requestBodyBytes;
            method = #post;
            transform = null;
        };

        Cycles.add(5_000_000); // Increased cycles for larger response
        try {
            let httpResponse = await management_canister.http_request(httpRequest);
            if (httpResponse.status == 200) {
                let responseText = bytesToText(httpResponse.body);
                switch (parseAIResponse(submission_id, responseText)) {
                    case (#ok(result)) { #ok(result) };
                    case (#err(error)) { #err("Failed to parse AI response: " # error) };
                }
            } else {
                #err("HTTP Error: Status " # Nat.toText(httpResponse.status))
            }
        } catch (error) {
            #err("Network Error: " # Error.message(error))
        }
    };

    // Enhanced AI response parsing
    private func parseAIResponse(submission_id: Text, jsonResponse: Text) : Result.Result<AIVerificationResult, Text> {
        // Enhanced JSON parsing (still simplified but more robust)
        var owner: Text = "Unknown";
        var location: Text = "Unknown";
        var issue_date: Text = "Unknown";
        var confidence_score: Nat = 0;
        var verdict_text: Text = "requires_review";
        var red_flags: [Text] = [];
        var extracted_fields: [(Text, Text)] = [];

        // Basic parsing logic (in production, consider using a proper JSON parser)
        let lines = Text.split(jsonResponse, #char '\n');
        for (line in lines) {
            if (Text.contains(line, #text "\"owner\":")) {
                owner := extractJSONValue(line, "owner");
            };
            if (Text.contains(line, #text "\"location\":")) {
                location := extractJSONValue(line, "location");
            };
            if (Text.contains(line, #text "\"issue_date\":")) {
                issue_date := extractJSONValue(line, "issue_date");
            };
            if (Text.contains(line, #text "\"confidence_score\":")) {
                let score_text = extractJSONValue(line, "confidence_score");
                switch (Nat.fromText(score_text)) {  
                    case (?f) { confidence_score := f };
                    case null { confidence_score := 5 };
                };
            };
            if (Text.contains(line, #text "\"verdict\":")) {
                verdict_text := extractJSONValue(line, "verdict");
            };
        };

        let verdict: VerificationVerdict = switch (verdict_text) {
            case ("valid") { #valid };
            case ("suspicious") { #suspicious };
            case ("invalid") { #invalid };
            case (_) { #requires_review };
        };

        #ok({
            submission_id = submission_id;
            owner = owner;
            location = location;
            issue_date = issue_date;
            confidence_score = confidence_score;
            verdict = verdict;
            ai_response = jsonResponse;
            verification_timestamp = Nat64.fromIntWrap(Time.now());
            red_flags = red_flags;
            extracted_fields = extracted_fields;
        })
    };

    private func extractJSONValue(line: Text, field: Text) : Text {
        let pattern = "\"" # field # "\":";
        if (Text.contains(line, #text pattern)) {
            let parts = Text.split(line, #text pattern);
            switch (parts.next()) {
                case (?_) {
                    switch (parts.next()) {
                        case (?value) {
                            let cleaned = Text.replace(value, #text "\"", "");
                            let cleaned2 = Text.replace(cleaned, #text ",", "");
                            let cleaned3 = Text.replace(cleaned2, #text "}", "");
                            Text.trim(cleaned3, #text " ")
                        };
                        case null { "Unknown" };
                    };
                };
                case null { "Unknown" };
            };
        } else {
            "Unknown"
        }
    };

    // Enhanced admin functions
    public shared(msg) func reviewSubmission(submission_id: Text, new_status_text: Text, admin_notes: ?Text) : async Result.Result<PropertySubmission, Text> {
        if (msg.caller != owner) {
            return #err("Unauthorized: Only the canister owner can review submissions");
        };

        let new_status: SubmissionStatus = switch (new_status_text) {
            case ("verified") { #verified };
            case ("rejected") { #rejected };
            case ("requires_review") { #requires_human_review };
            case (_) { return #err("Invalid status: Must be 'verified', 'rejected', or 'requires_review'") };
        };

        switch (updateSubmissionStatus(submission_id, new_status)) {
            case (#ok(_)) {
                let notes_text = Option.get(admin_notes, "No additional notes");
                logEvent(#admin_review, "Admin review completed: " # new_status_text # " - " # notes_text, ?submission_id, ?msg.caller);
                
                switch (submissions.get(submission_id)) {
                    case null { #err("Submission not found after update") };
                    case (?updated_submission) { #ok(updated_submission) };
                }
            };
            case (#err(error)) { #err(error) };
        }
    };

    // UI-friendly query functions
    public query func getDashboardData(user: ?Principal) : async DashboardData {
        let all_submissions = Iter.toArray(submissions.entries());
        let total_submissions = all_submissions.size();
        
        var pending_count = 0;
        var verified_count = 0;
        var rejected_count = 0;
        let user_submissions_buffer = Buffer.Buffer<PropertySubmission>(0);
        let recent_submissions_buffer = Buffer.Buffer<PropertySubmission>(5);
        
        var count = 0;
        for ((id, submission) in all_submissions.vals()) {
            switch (submission.status) {
                case (#pending or #ai_verifying or #requires_human_review or #admin_reviewing) { pending_count += 1 };
                case (#verified or #ai_verified) { verified_count += 1 };
                case (#rejected or #ai_rejected) { rejected_count += 1 };
            };
            
            // Add to user submissions if user matches
            switch (user) {
                case (?u) {
                    if (Principal.equal(submission.submitter, u)) {
                        user_submissions_buffer.add(submission);
                    };
                };
                case null { };
            };
            
            // Add to recent submissions (last 5)
            if (count < 5) {
                recent_submissions_buffer.add(submission);
                count += 1;
            };
        };

        // Get recent events (last 10)
        let recent_events = Array.sort<EventLog>(
            Array.map<(Nat, EventLog), EventLog>(
                Iter.toArray(events.entries()),
                func((id, event)) = event
            ),
            func(a, b) = Nat64.compare(b.timestamp, a.timestamp) // Descending order
        );
        let recent_events_slice = if (recent_events.size() > 10) {
            Array.subArray(recent_events, 0, 10)
        } else {
            recent_events
        };

        {
            total_submissions = total_submissions;
            pending_submissions = pending_count;
            verified_submissions = verified_count;
            rejected_submissions = rejected_count;
            recent_submissions = Buffer.toArray(recent_submissions_buffer);
            recent_events = recent_events_slice;
            user_submissions = Buffer.toArray(user_submissions_buffer);
        }
    };

    public query func getSubmissionsWithFilters(filters: SubmissionFilters, limit: ?Nat, offset: ?Nat) : async [PropertySubmission] {
        let all_submissions = Array.map<(Text, PropertySubmission), PropertySubmission>(
            Iter.toArray(submissions.entries()),
            func((id, submission)) = submission
        );

        // Apply filters
        let filtered = Array.filter<PropertySubmission>(all_submissions, func(submission) {
            // Status filter
            switch (filters.status) {
                case (?status) {
                    if (not statusEquals(submission.status, status)) return false;
                };
                case null { };
            };

            // Submitter filter
            switch (filters.submitter) {
                case (?submitter) {
                    if (not Principal.equal(submission.submitter, submitter)) return false;
                };
                case null { };
            };

            // Date filters
            switch (filters.date_from) {
                case (?from) {
                    if (submission.timestamp < from) return false;
                };
                case null { };
            };

            switch (filters.date_to) {
                case (?to) {
                    if (submission.timestamp > to) return false;
                };
                case null { };
            };

            // Confidence score filters (check if verification exists)
            switch (verifications.get(submission.id)) {
                case (?verification) {
                    switch (filters.confidence_min) {
                        case (?min) {
                            if (verification.confidence_score < min) return false;
                        };
                        case null { };
                    };
                    switch (filters.confidence_max) {
                        case (?max) {
                            if (verification.confidence_score > max) return false;
                        };
                        case null { };
                    };
                };
                case null {
                    // If no verification exists, exclude if confidence filters are set
                    if (Option.isSome(filters.confidence_min) or Option.isSome(filters.confidence_max)) {
                        return false;
                    };
                };
            };

            true
        });

        // Sort by timestamp (newest first)
        let sorted = Array.sort<PropertySubmission>(filtered, func(a, b) = Nat64.compare(b.timestamp, a.timestamp));

        // Apply pagination
        let start_index = Option.get(offset, 0);
        let max_results = Option.get(limit, sorted.size());
        let end_index = Nat.min(start_index + max_results, sorted.size());

        if (start_index >= sorted.size()) {
            []
        } else {
            Array.subArray(sorted, start_index, end_index - start_index)
        }
    };

    private func statusEquals(a: SubmissionStatus, b: SubmissionStatus) : Bool {
        statusToText(a) == statusToText(b)
    };

    // Enhanced query functions
    public query func getSubmissionWithVerification(submission_id: Text) : async ?{submission: PropertySubmission; verification: ?AIVerificationResult} {
        switch (submissions.get(submission_id)) {
            case null { null };
            case (?submission) {
                ?{
                    submission = submission;
                    verification = verifications.get(submission_id);
                }
            };
        }
    };

    public query func getUserSubmissions(user: Principal) : async [PropertySubmission] {
        Array.filter<PropertySubmission>(
            Array.map<(Text, PropertySubmission), PropertySubmission>(
                Iter.toArray(submissions.entries()),
                func((id, submission)) = submission
            ),
            func(submission) = Principal.equal(submission.submitter, user)
        )
    };

    public query func getSubmissionStats() : async {
        total: Nat;
        by_status: [(Text, Nat)];
        by_verdict: [(Text, Nat)];
        average_confidence: Float;
    } {
        let all_submissions = Iter.toArray(submissions.entries());
        let total = all_submissions.size();
        
        // Count by status
        var status_counts = HashMap.HashMap<Text, Nat>(8, Text.equal, Text.hash);
        var verdict_counts = HashMap.HashMap<Text, Nat>(4, Text.equal, Text.hash);
        var total_confidence: Nat = 0;
        var verification_count = 0;

        for ((id, submission) in all_submissions.vals()) {
            let status_text = statusToText(submission.status);
            let current_count = Option.get(status_counts.get(status_text), 0);
            status_counts.put(status_text, current_count + 1);

            // Count verifications
            switch (verifications.get(submission.id)) {
                case (?verification) {
                    let verdict_text = verdictToText(verification.verdict);
                    let current_verdict_count = Option.get(verdict_counts.get(verdict_text), 0);
                    verdict_counts.put(verdict_text, current_verdict_count + 1);
                    total_confidence += verification.confidence_score;
                    verification_count += 1;
                };
                case null { };
            };
        };

        let average_confidence = if (verification_count > 0) {
            total_confidence / verification_count
        } else {
            0
        };

        {
            total = total;
            by_status = Iter.toArray(status_counts.entries());
            by_verdict = Iter.toArray(verdict_counts.entries());
            average_confidence = Float.fromInt(average_confidence);
        }
    };

    // Existing query functions (maintained for compatibility)
    public query func getAllSubmissions() : async [PropertySubmission] {
        Array.map<(Text, PropertySubmission), PropertySubmission>(
            Iter.toArray(submissions.entries()),
            func((id, submission)) = submission
        )
    };

    public query func getVerifiedSubmissions() : async [PropertySubmission] {
        Array.filter<PropertySubmission>(
            Array.map<(Text, PropertySubmission), PropertySubmission>(
                Iter.toArray(submissions.entries()),
                func((id, submission)) = submission
            ),
            func(submission) = switch (submission.status) {
                case (#verified or #ai_verified) { true };
                case (_) { false };
            }
        )
    };

    public query func getSubmissionById(submission_id: Text) : async ?PropertySubmission {
        submissions.get(submission_id)
    };

    public query func getSubmissionByHash(ipfs_hash: Text) : async [PropertySubmission] {
        Array.filter<PropertySubmission>(
            Array.map<(Text, PropertySubmission), PropertySubmission>(
                Iter.toArray(submissions.entries()),
                func((id, submission)) = submission
            ),
            func(submission) = switch (submission.ipfs_hash) {
                case (?hash) { hash == ipfs_hash };
                case null { false };
            }
        )
    };

    public query func getVerificationResult(submission_id: Text) : async ?AIVerificationResult {
        verifications.get(submission_id)
    };

    public query func getEventLogs() : async [EventLog] {
        Array.map<(Nat, EventLog), EventLog>(
            Iter.toArray(events.entries()),
            func((id, event)) = event
        )
    };

    // Additional utility functions for better UX/UI integration
    // public shared query(msg) func searchSubmissions(query: Text) : async [PropertySubmission] {
    //     let query_lower = Text.map(query, func(c) = Char.toLower(c));
    //     Array.filter<PropertySubmission>(
    //         Array.map<(Text, PropertySubmission), PropertySubmission>(
    //             Iter.toArray(submissions.entries()),
    //             func((id, submission)) = submission
    //         ),
    //         func(submission) {
    //             let title_lower = Text.map(submission.document_title, func(c) = Char.toLower(c));
    //             let text_lower = Text.map(submission.document_text, func(c) = Char.toLower(c));
    //             Text.contains(title_lower, #text query_lower) or Text.contains(text_lower, #text query_lower)
    //         }
    //     )
    // };

    public query func getSubmissionsByStatus(status_text: Text) : async [PropertySubmission] {
        Array.filter<PropertySubmission>(
            Array.map<(Text, PropertySubmission), PropertySubmission>(
                Iter.toArray(submissions.entries()),
                func((id, submission)) = submission
            ),
            func(submission) = statusToText(submission.status) == status_text
        )
    };

    public query func getRecentActivity(limit: ?Nat) : async [EventLog] {
        let max_events = Option.get(limit, 20);
        let all_events = Array.sort<EventLog>(
            Array.map<(Nat, EventLog), EventLog>(
                Iter.toArray(events.entries()),
                func((id, event)) = event
            ),
            func(a, b) = Nat64.compare(b.timestamp, a.timestamp)
        );
        
        if (all_events.size() > max_events) {
            Array.subArray(all_events, 0, max_events)
        } else {
            all_events
        }
    };

    // Batch operations for admin efficiency
    shared(msg) func batchReview(
        submission_ids: [Text], 
        new_status_text: Text, 
        admin_notes: ?Text
    ) : async [(Text, Result.Result<Text, Text>)] {
        if (msg.caller != owner) {
            return Array.map<Text, (Text, Result.Result<Text, Text>)>(
                submission_ids,
                func(id) = (id, #err("Unauthorized: Only the canister owner can review submissions"))
            );
        };

        var results : [(Text, {#err : Text; #ok : PropertySubmission})] = await batchReview2(submission_ids);

        Array.map<(Text, {#err : Text; #ok : PropertySubmission}), (Text, Result.Result<Text, Text>)>(
            results,
            func((id, res)) = (id, switch (res) {
                case (#ok(submission)) { #ok(statusToText(submission.status)) };
                case (#err(error)) { #err(error) };
            })
        )
    };

    func batchReview2(submission_ids : [Text]) : async [(Text, {#err : Text; #ok : PropertySubmission})] {
        var results : [(Text, {#err : Text; #ok : PropertySubmission})] = [];
        for (submission_id in submission_ids.vals()) {
            let sub = await reviewSubmission(submission_id, "verified", null);
            results := Array.append(results, [(submission_id, sub)]);
        };
        return results;
    };

    //  switch ( ) {
    //                 case (#ok(submission)) { (submission_id, #ok(submission)) };
    //                 case (#err(error)) { (submission_id, #err(error)) };
                // }

    // Configuration functions
    public shared(msg) func updateSettings(key: Text, value: Text) : async Result.Result<Text, Text> {
        if (msg.caller != owner) {
            return #err("Unauthorized: Only the canister owner can update settings");
        };
        settings.put(key, value);
        logEvent(#admin_review, "Settings updated: " # key, null, ?msg.caller);
        #ok("Settings updated successfully")
    };

    public query func getSettings() : async [(Text, Text)] {
        Iter.toArray(settings.entries())
    };

    public query func getSetting(key: Text) : async ?Text {
        settings.get(key)
    };

    // Export/Import functions for data management
    public query func exportSubmissions() : async [PropertySubmission] {
        Array.map<(Text, PropertySubmission), PropertySubmission>(
            Iter.toArray(submissions.entries()),
            func((id, submission)) = submission
        )
    };

    public query func exportVerifications() : async [AIVerificationResult] {
        Array.map<(Text, AIVerificationResult), AIVerificationResult>(
            Iter.toArray(verifications.entries()),
            func((id, verification)) = verification
        )
    };

    // Health check and metrics
    public query func getCanisterHealth() : async {
        submissions_count: Nat;
        verifications_count: Nat;
        events_count: Nat;
        memory_usage: Text;
        last_activity: ?Nat64;
    } {
        let last_activity = if (events.size() > 0) {
            let sorted_events = Array.sort<EventLog>(
                Array.map<(Nat, EventLog), EventLog>(
                    Iter.toArray(events.entries()),
                    func((id, event)) = event
                ),
                func(a, b) = Nat64.compare(b.timestamp, a.timestamp)
            );
            if (sorted_events.size() > 0) {
                ?sorted_events[0].timestamp
            } else {
                null
            }
        } else {
            null
        };

        {
            submissions_count = submissions.size();
            verifications_count = verifications.size();
            events_count = events.size();
            memory_usage = "Stable storage in use"; // Could be enhanced with actual memory metrics
            last_activity = last_activity;
        }
    };

    // Notification system for real-time updates
    public type NotificationSubscription = {
        user: Principal;
        events: [EventType];
        active: Bool;
    };

    private stable var notifications_entries: [(Principal, NotificationSubscription)] = [];
    private var notifications = HashMap.HashMap<Principal, NotificationSubscription>(10, Principal.equal, Principal.hash);

    public shared(msg) func subscribeToNotifications(event_types: [EventType]) : async Result.Result<Text, Text> {
        let subscription: NotificationSubscription = {
            user = msg.caller;
            events = event_types;
            active = true;
        };
        notifications.put(msg.caller, subscription);
        #ok("Successfully subscribed to notifications")
    };

    public shared(msg) func unsubscribeFromNotifications() : async Result.Result<Text, Text> {
        notifications.delete(msg.caller);
        #ok("Successfully unsubscribed from notifications")
    };

    public query func getNotificationSubscription(user: Principal) : async ?NotificationSubscription {
        notifications.get(user)
    };

    // Rate limiting for submissions
    private stable var rate_limits_entries: [(Principal, (Nat, Nat64))] = []; // (user, (count, last_reset))
    private var rate_limits = HashMap.HashMap<Principal, (Nat, Nat64)>(10, Principal.equal, Principal.hash);
    private let MAX_SUBMISSIONS_PER_HOUR = 10;
    private let HOUR_IN_NANOSECONDS = 3600_000_000_000;

    private func checkRateLimit(user: Principal) : Bool {
        let now = Nat64.fromIntWrap(Time.now());
        switch (rate_limits.get(user)) {
            case null {
                rate_limits.put(user, (1, now));
                true
            };
            case (?(count, last_reset)) {
                if (Nat64.greater(now - last_reset, Nat64.fromNat(HOUR_IN_NANOSECONDS))) {
                    // Reset the counter
                    rate_limits.put(user, (1, now));
                    true
                } else if (count < MAX_SUBMISSIONS_PER_HOUR) {
                    // Increment the counter
                    rate_limits.put(user, (count + 1, last_reset));
                    true
                } else {
                    // Rate limit exceeded
                    false
                }
            };
        }
    };

    public query func getRateLimitStatus(user: Principal) : async {remaining: Nat; reset_time: Nat64} {
        let now = Nat64.fromIntWrap(Time.now());
        switch (rate_limits.get(user)) {
            case null {
                {
                    remaining = MAX_SUBMISSIONS_PER_HOUR;
                    reset_time = now + Nat64.fromNat(HOUR_IN_NANOSECONDS);
                }
            };
            case (?(count, last_reset)) {
                if (Nat64.greater(now - last_reset, Nat64.fromNat(HOUR_IN_NANOSECONDS))) {
                    {
                        remaining = MAX_SUBMISSIONS_PER_HOUR;
                        reset_time = now + Nat64.fromNat(HOUR_IN_NANOSECONDS);
                    }
                } else {
                    {
                        remaining = if (count < MAX_SUBMISSIONS_PER_HOUR) {
                            MAX_SUBMISSIONS_PER_HOUR - count
                        } else {
                            0
                        };
                        reset_time = last_reset + Nat64.fromNat(HOUR_IN_NANOSECONDS);
                    }
                }
            };
        }
    };

    // Enhanced system hooks for rate limits
    system func preupgrade() {
        submissions_entries := Iter.toArray(submissions.entries());
        verifications_entries := Iter.toArray(verifications.entries());
        events_entries := Iter.toArray(events.entries());
        settings_entries := Iter.toArray(settings.entries());
        notifications_entries := Iter.toArray(notifications.entries());
        rate_limits_entries := Iter.toArray(rate_limits.entries());
    };

    system func postupgrade() {
        submissions := HashMap.fromIter<Text, PropertySubmission>(submissions_entries.vals(), submissions_entries.size(), Text.equal, Text.hash);
        verifications := HashMap.fromIter<Text, AIVerificationResult>(verifications_entries.vals(), verifications_entries.size(), Text.equal, Text.hash);
        events := HashMap.fromIter<Nat, EventLog>(events_entries.vals(), events_entries.size(), Nat.equal, Hash.hash);
        settings := HashMap.fromIter<Text, Text>(settings_entries.vals(), settings_entries.size(), Text.equal, Text.hash);
        notifications := HashMap.fromIter<Principal, NotificationSubscription>(notifications_entries.vals(), notifications_entries.size(), Principal.equal, Principal.hash);
        rate_limits := HashMap.fromIter<Principal, (Nat, Nat64)>(rate_limits_entries.vals(), rate_limits_entries.size(), Principal.equal, Principal.hash);
        
        // Clear temporary arrays
        submissions_entries := [];
        verifications_entries := [];
        events_entries := [];
        settings_entries := [];
        notifications_entries := [];
        rate_limits_entries := [];
    };
}