import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";

actor class Rwa() {
    // --- RWA Types ---
    public type Rwa = {
        #Property: PropertyMetadata;
        #AcademicCredential: AcademicCredentialMetadata;
        #ProfessionalLicense: ProfessionalLicenseMetadata;
    };

    public type PropertyMetadata = {
        propertyAddress: Text;
        propertyValue: Nat; // in cents
        legalDocuments: Text; // IPFS link or hash to legal docs
        description: Text;
        attributes: [(Text, Text)]; // e.g., [("squareFeet", "2000"), ("bedrooms", "4")]
    };

    public type AcademicCredentialMetadata = {
        studentName: Text;
        institution: Text;
        degree: Text;
        major: Text;
        graduationYear: Nat;
        transcriptHash: Text; // IPFS hash of the transcript
    };

    public type ProfessionalLicenseMetadata = {
        licenseHolderName: Text;
        licenseType: Text; // e.g., "Medical Doctor", "Certified Public Accountant"
        licenseNumber: Text;
        issuingBody: Text;
        issueDate: Time.Time;
        expirationDate: Time.Time;
    };

    // --- RWA Submission Types ---
    public type RwaSubmission = {
        id: Text;
        submitter: Principal;
        rwa: Rwa;
        document_text: Text;
        ipfs_hash: ?Text;
        timestamp: Nat64;
        status: SubmissionStatus;
        file_type: ?Text;
        file_size: ?Nat;
        submission_notes: ?Text;
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

    // --- AI Verification Types ---
    public type AIVerificationResult = {
        submission_id: Text;
        confidence_score: Nat;
        verdict: VerificationVerdict;
        ai_response: Text;
        verification_timestamp: Nat64;
        red_flags: [Text];
        extracted_fields: [(Text, Text)];
    };

    public type VerificationVerdict = {
        #valid;
        #suspicious;
        #invalid;
        #requires_review;
    };
};
