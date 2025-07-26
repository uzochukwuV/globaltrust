/**
 * Module     : types.mo
 * Copyright  : 2025 YourTeam
 * License    : Apache 2.0 with LLVM Exception
 * Description: Types for Identity Verifier canister
 */

module {
    public type Identity = {
        id: Principal;
        owner: Principal;
        createdAt: Nat;
        updatedAt: Nat;
        verified: Bool;
    };

    public type VerifiableCredential = {
        id: Text;
        ownerId: Principal;
        credentialType: Text;
        issuer: Text;
        issuedAt: Nat;
        expirationDate: ?Nat;
        credentialHash: Text;
        status: CredentialStatus;
    };

    public type CredentialStatus = {
        #Valid;
        #Revoked;
        #Suspended;
    };

    public type Response = {
        #Ok;
        #Unauthorized;
        #Expired;
        #NotConfirmed;
        #InvalidSession;
    };

    public type Errors = {
        #Unauthorized;
        #Expired;
        #NotConfirmed;
        #InvalidSession;
        #IdentityAlreadyExists;
        #IdentityNotFound;
        #CredentialAlreadyExists;
        #CredentialNotFound;
    };
};