// src/gt_backend/common/types.mo
// Shared types, errors, RBAC roles, events, and constants for GlobalTrust

import Prim "mo:prim";

/// Alias for results used throughout the backend
public type Result<T, E> = { #ok: T; #err: E };

/// Common error types
public type CommonError = {
  #Unauthorized;
  #NotFound;
  #InvalidRequest;
  #AlreadyExists;
  #UpgradeInProgress;
  #InternalError : Text;
  #InsufficientCycles;
  #TemporarilyUnavailable;
};

/// RBAC role definitions
public type Role = {
  #Admin;
  #Issuer;
  #Verifier;
  #Oracle;
  #DAO;
  #User;
};

/// RBAC error types
public type RBACError = {
  #Unauthorized;
  #RoleNotFound;
  #RoleAlreadyAssigned;
  #RoleNotAssigned;
  #CallerNotPrincipal;
  #CannotModifyDAO;
  #InternalError : Text;
};

/// Credential registry errors
public type CredentialError = {
  #Unauthorized;
  #NotFound;
  #Revoked;
  #Expired;
  #AlreadyExists;
  #InvalidStatus;
  #InvalidIssuer;
  #StatusListUnavailable;
  #InternalError : Text;
};

/// NFT canister error types
public type NFTError = {
  #Unauthorized;
  #NotFound;
  #Frozen;
  #Collateralized;
  #LienActive;
  #AlreadyExists;
  #TransferBlocked;
  #InvalidMetadata;
  #InternalError : Text;
};

/// Registry/Status errors
public type RegistryError = {
  #NotFound;
  #VersionMismatch;
  #InvalidBitIndex;
  #InternalError : Text;
};

/// Event types for system-wide event log
public type EventType = {
  #CredentialIssued;
  #CredentialRevoked;
  #CredentialQueried;
  #NFTMinted;
  #NFTTransferred;
  #NFTFrozen;
  #NFTUnfrozen;
  #LienSet;
  #CollateralSet;
  #VerificationSubmitted;
  #VerificationCompleted;
  #StatusListUpdated;
  #RBACChanged;
  #DAOProposalCreated;
  #DAOProposalExecuted;
  #UpgradeStarted;
  #UpgradeCompleted;
  #CyclesReceived;
  #CyclesRefunded;
  #Error : Text;
  // (Extend as needed)
};

/// Event log entry
public type Event = {
  id : Nat; // Monotonic event id
  timestamp : Nat64;
  actor : ?Principal;
  typ : EventType;
  details : Text;
};

/// Common constants
public let MAX_EVENT_LOG : Nat = 10_000;
public let DEFAULT_STATUS_LIST_SIZE : Nat = 16_384; // 2^14, can be tuned
public let MAX_ROLES_PER_PRINCIPAL : Nat = 8;
public let DAO_PRINCIPAL : Text = "dao_principal"; // Placeholder; set by DAO canister

/// RBAC role names as Text
public module RoleNames {
  public let Admin = "Admin";
  public let Issuer = "Issuer";
  public let Verifier = "Verifier";
  public let Oracle = "Oracle";
  public let DAO = "DAO";
  public let User = "User";
}