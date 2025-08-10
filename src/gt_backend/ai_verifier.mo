import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Char "mo:base/Char";
import Float "mo:base/Float";
import LLM "canister:llm";
import Rwa "canister:rwa";

actor class AIVerifier() {

    // HTTP types
    public type HttpRequestArgs = {
        url: Text;
        max_response_bytes: ?Nat64;
        headers: [HttpHeader];
        body: ?[Nat8];
        method: HttpMethod;
        transform: ?TransformContext;
    };

    public type HttpHeader = { name: Text; value: Text; };
    public type HttpMethod = { #get; #post; #head; };
    public type HttpResponsePayload = { status: Nat; headers: [HttpHeader]; body: [Nat8]; };

    public type TransformContext = {
        function: shared query (TransformArgs) -> async HttpResponsePayload;
        context: Blob;
    };

    public type TransformArgs = {
        response: HttpResponsePayload;
        context: Blob;
    };

    private let management_canister: actor { http_request: HttpRequestArgs -> async HttpResponsePayload } = actor("aaaaa-aa");

    public func prompt(prompt : Text) : async Text {
        await LLM.v0_chat({messages =[{content = prompt; role = #user}]; model = "Llama3_1_8B"});
    };

    public func verifyDocument(submission_id: Text, rwa: Rwa.Rwa, document_text: Text) : async Result.Result<Rwa.AIVerificationResult, Text> {

        let prompt_text = switch(rwa) {
            case (#Property(prop)) {
                "You are an expert property document verification AI. Analyze the following property document for authenticity and extract key information.\n\n" #
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
            };
            case (#AcademicCredential(cred)) {
                "You are an expert academic credential verification AI. Analyze the following academic document for authenticity and extract key information.\n\n" #
                "Document to analyze:\n" # document_text # "\n\n" #
                "Please provide a detailed analysis and return a JSON object with the following fields:\n" #
                "- is_authentic: boolean (true if document appears genuine)\n" #
                "- student_name: string\n" #
                "- institution: string\n" #
                "- degree: string\n" #
                "- major: string\n" #
                "- graduation_year: number\n" #
                "- red_flags: array of strings (specific issues found)\n" #
                "- confidence_score: float (0 to 100)\n" #
                "- verdict: string ('valid', 'suspicious', 'invalid', or 'requires_review')\n" #
                "- extracted_fields: object with additional key-value pairs found in the document";
            };
            case (#ProfessionalLicense(lic)) {
                "You are an expert professional license verification AI. Analyze the following license document for authenticity and extract key information.\n\n" #
                "Document to analyze:\n" # document_text # "\n\n" #
                "Please provide a detailed analysis and return a JSON object with the following fields:\n" #
                "- is_authentic: boolean (true if document appears genuine)\n" #
                "- license_holder_name: string\n" #
                "- license_type: string\n" #
                "- license_number: string\n" #
                "- issuing_body: string\n" #
                "- issue_date: string\n" #
                "- expiration_date: string\n" #
                "- red_flags: array of strings (specific issues found)\n" #
                "- confidence_score: float (0 to 100)\n" #
                "- verdict: string ('valid', 'suspicious', 'invalid', or 'requires_review')\n" #
                "- extracted_fields: object with additional key-value pairs found in the document";
            };
        };

        let requestBody = "{\"messages\":[{\"role\":\"system\",\"content\":\"You are a document verification AI. Provide accurate and reliable analysis in JSON format.\"},{\"role\":\"user\",\"content\":\"" # prompt_text # "\"}]}";

        let response = await prompt(requestBody);

        switch (parseAIResponse(submission_id, response)) {
                case (#ok(result)) { #ok(result) };
                case (#err(error)) { #err("Failed to parse AI response: " # error) };
        }
    };

    private func parseAIResponse(submission_id: Text, jsonResponse: Text) : Result.Result<Rwa.AIVerificationResult, Text> {
        var confidence_score: Nat = 0;
        var verdict_text: Text = "requires_review";
        var red_flags: [Text] = [];
        var extracted_fields: [(Text, Text)] = [];

        // Basic parsing logic (in production, consider using a proper JSON parser)
        let lines = Text.split(jsonResponse, #char '\n');
        for (line in lines) {
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

        let verdict: Rwa.VerificationVerdict = switch (verdict_text) {
            case ("valid") { #valid };
            case ("suspicious") { #suspicious };
            case ("invalid") { #invalid };
            case (_) { #requires_review };
        };

        #ok({
            submission_id = submission_id;
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

    // HTTPS Outcall for external data verification
    public shared(msg) func crossReferenceWithExternalAPI(url: Text) : async Result.Result<Text, Text> {
        let request_headers = [];
        let request = {
            url = url;
            max_response_bytes = null;
            method = #get;
            headers = request_headers;
            body = null;
            transform = null;
        };

        let result = await management_canister.http_request(request);

        switch(result) {
            case(#ok(response)) {
                if(response.status != 200) {
                    return #err("Request failed with status " # Nat.toText(response.status));
                };
                let text_decoder = Text.decodeUtf8(Blob.fromArray(response.body));
                switch(text_decoder) {
                    case(?text) {
                        return #ok(text);
                    };
                    case(null) {
                        return #err("Failed to decode response body");
                    };
                };
            };
            case(#err(err_message)) {
                return #err(err_message);
            };
        }
    };
};
