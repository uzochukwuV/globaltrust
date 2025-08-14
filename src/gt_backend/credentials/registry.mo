// Credential/Attestation Registry Canister
// Stores W3C VC-style credentials as commitments, with revocation/status compliance, RBAC, and certified endpoints

import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Time "mo:base/Time";

// RBAC role constants (reuse from common if available)
let ROLE_ISSUER : Text = "issuer";
let ROLE_ADMIN : Text = "admin";
let ROLE_DAO : Text = "dao";

type CredentialId = Nat;
type StatusListId = Nat;
type BitChunk = [Nat8];
type PrincipalDID = Text;
type KeyHandle = Text;

// Credential structure
type Credential = {
  id: CredentialId;
  subject: Principal;
  issuer: Principal;
  type_: Text;
  schema: Text;
  issuedAt: Nat64;
  expiresAt: ?Nat64;
  commitmentHash: Text;
  statusIndex: Nat;
  statusListId: StatusListId;
};

// Metadata for credential verification
type CredentialMetadata = {
  subject: Principal;
  issuer: Principal;
  type_: Text;
  schema: Text;
  issuedAt: Nat64;
  expiresAt: ?Nat64;
  statusIndex: Nat;
  statusListId: StatusListId;
};

type StatusList = {
  listId: StatusListId;
  version: Nat;
  bitChunks: [var BitChunk];
};

type Event = {
  kind: Text;
  data: Text;
  timestamp: Nat64;
};

type DIDMapping = {
  did: PrincipalDID;
  vetKeyHandle: ?KeyHandle;
};

type CertifiedStatus = {
  status: Bool;
  certificate: Blob;
};

/////////////////////////////
// Stable Storage

stable var credentials = HashMap.HashMap<CredentialId, Credential>(0, Nat.equal, Hash.hash);
stable var credentialsBySubject = HashMap.HashMap<Principal, [CredentialId]>(0, Principal.equal, Principal.hash);
stable var credentialsByHash = HashMap.HashMap<Text, CredentialId>(0, Text.equal, Text.hash);
stable var statusLists = HashMap.HashMap<StatusListId, StatusList>(0, Nat.equal, Hash.hash);
stable var statusMapping = HashMap.HashMap<CredentialId, (StatusListId, Nat)>(0, Nat.equal, Hash.hash);
stable var currentStatusListId : StatusListId = 0;

stable var didMappings = HashMap.HashMap<Principal, DIDMapping>(0, Principal.equal, Principal.hash);
stable var principalByDID = HashMap.HashMap<Text, Principal>(0, Text.equal, Text.hash);

stable var events: [Event] = [];
stable var credentialCounter: CredentialId = 0;
stable var statusListCounter: StatusListId = 0;

/////////////////////////////
// Utility Functions

func requireRole(caller: Principal, role: Text) {
  // TODO: Integrate with RBAC from DAO or main (stub now)
  if (role == ROLE_ISSUER and not Principal.isController(caller)) {
    // Only controller can issue in this stub; update for real RBAC
    throw Error.reject("Issuer-only function.");
  };
  if ((role == ROLE_ADMIN or role == ROLE_DAO) and not Principal.isController(caller)) {
    throw Error.reject("Admin/DAO-only function.");
  };
};

func emitEvent(kind: Text, data: Text) {
  let now = Time.now();
  events := Array.append<Event>(events, [{ kind; data; timestamp = now }]);
};

func allocateStatusIndex(list: StatusList) : Nat {
  for (i in Iter.range(0, Array.size(list.bitChunks) - 1)) {
    let chunk = list.bitChunks[i];
    for (j in Iter.range(0, Array.size(chunk) - 1)) {
      if (chunk[j] == 0) return (i * Array.size(chunk)) + j;
    };
  };
  // Expand status list if needed
  let newChunk : BitChunk = Array.init<Nat8>(128, 0);
  list.bitChunks := Array.append<BitChunk>(list.bitChunks, [newChunk]);
  return (Array.size(list.bitChunks) - 1) * Array.size(newChunk);
};

func setBit(chunk: BitChunk, idx: Nat, value: Bool) : BitChunk {
  var c = chunk;
  let byteIdx = idx / 8;
  let bitIdx = idx % 8;
  if (byteIdx >= Array.size(c)) return c;
  let mask = 1 << bitIdx;
  if (value) {
    c[byteIdx] := c[byteIdx] | mask;
  } else {
    c[byteIdx] := c[byteIdx] & (~mask);
  };
  c;
};

func getBit(chunk: BitChunk, idx: Nat) : Bool {
  let byteIdx = idx / 8;
  let bitIdx = idx % 8;
  if (byteIdx >= Array.size(chunk)) return false;
  let mask = 1 << bitIdx;
  (chunk[byteIdx] & mask) != 0;
};

/////////////////////////////
// Main Canister Logic

// Candid: Issue a new status list, returns listId
public func newStatusList() : async StatusListId {
  requireRole(Principal.fromActor(this), ROLE_ISSUER);
  let listId = statusListCounter;
  let newList : StatusList = {
    listId;
    version = 1;
    bitChunks = [Array.init<Nat8>(128, 0)];
  };
  statusLists.put(listId, newList);
  statusListCounter += 1;
  currentStatusListId := listId;
  emitEvent("newStatusList", Nat.toText(listId));
  listId;
};

/// Candid: Set credential status (revoked/unrevoked) in a status list
public func setStatus(listId: StatusListId, index: Nat, revoked: Bool) : async () {
  requireRole(Principal.fromActor(this), ROLE_ISSUER);
  let listOpt = statusLists.get(listId);
  switch (listOpt) {
    case null { throw Error.reject("Status list not found."); };
    case (?list) {
      let chunkIdx = index / 128;
      let bitIdx = index % 128;
      if (chunkIdx >= Array.size(list.bitChunks)) throw Error.reject("Index out of range.");
      let chunk = list.bitChunks[chunkIdx];
      let updated = setBit(chunk, bitIdx, revoked);
      list.bitChunks[chunkIdx] := updated;
      emitEvent("setStatus", Nat.toText(listId) # ":" # Nat.toText(index) # ":" # (if revoked then "revoked" else "active"));
    }
  }
};

/// Candid: Get credential status from a status list (query, with certified_data)
public query func getStatus(listId: StatusListId, index: Nat) : async Bool {
  let listOpt = statusLists.get(listId);
  switch (listOpt) {
    case null { return false; };
    case (?list) {
      let chunkIdx = index / 128;
      let bitIdx = index % 128;
      if (chunkIdx >= Array.size(list.bitChunks)) return false;
      let chunk = list.bitChunks[chunkIdx];
      getBit(chunk, bitIdx)
    }
  }
};

/// Candid: Returns the current (latest) status listId
public query func currentListId() : async StatusListId {
  currentStatusListId;
};

/// Candid: Issue a credential (Issuer-only)
public func issueCredential(
  subject: Principal,
  type_: Text,
  schema: Text,
  commitmentHash: Text,
  expiresAt: ?Nat64
) : async CredentialId {
  requireRole(Principal.fromActor(this), ROLE_ISSUER);
  let id = credentialCounter;
  let issuer = Principal.fromActor(this);
  let issuedAt = Nat64.fromNat(Time.now());
  let listId = currentStatusListId;
  let statusList = statusLists.get(listId);
  let index = switch (statusList) {
    case null { throw Error.reject("No status list available."); };
    case (?list) { allocateStatusIndex(list) };
  };
  // Mark as active (not revoked)
  ignore setStatus(listId, index, false);
  let cred : Credential = {
    id; subject; issuer; type_; schema; issuedAt; expiresAt;
    commitmentHash; statusIndex = index; statusListId = listId;
  };
  credentials.put(id, cred);
  credentialsBySubject.put(subject, Array.append(credentialsBySubject.get(subject) ? [] : [], [id]));
  credentialsByHash.put(commitmentHash, id);
  statusMapping.put(id, (listId, index));
  credentialCounter += 1;
  emitEvent("issue", Nat.toText(id));
  id;
};

/// Candid: Revoke a credential (Issuer/Admin/DAO)
public func revokeCredential(id: CredentialId) : async () {
  let credOpt = credentials.get(id);
  switch (credOpt) {
    case null { throw Error.reject("Credential not found."); };
    case (?cred) {
      requireRole(Principal.fromActor(this), ROLE_ADMIN);
      ignore setStatus(cred.statusListId, cred.statusIndex, true);
      emitEvent("revoke", Nat.toText(id));
    }
  }
};

/// Candid: Get credential metadata by id
public query func getCredential(id: CredentialId) : async ?CredentialMetadata {
  switch (credentials.get(id)) {
    case null { null };
    case (?cred) {
      ?{
        subject = cred.subject;
        issuer = cred.issuer;
        type_ = cred.type_;
        schema = cred.schema;
        issuedAt = cred.issuedAt;
        expiresAt = cred.expiresAt;
        statusIndex = cred.statusIndex;
        statusListId = cred.statusListId;
      }
    }
  }
};

/// Candid: List credentials for a subject principal
public query func listBySubject(subject: Principal) : async [CredentialId] {
  credentialsBySubject.get(subject) ? []
};

/// Candid: Verify credential by commitmentHash (+optional issuer)
public query func verifyCredential(commitmentHash: Text, issuer: ?Principal) : async {
  exists: Bool;
  status: Bool;
  metadata: ?CredentialMetadata;
} {
  let idOpt = credentialsByHash.get(commitmentHash);
  switch (idOpt) {
    case null { return { exists = false; status = false; metadata = null }; };
    case (?id) {
      let cred = credentials.get(id);
      switch (cred) {
        case null { return { exists = false; status = false; metadata = null }; };
        case (?c) {
          if (Option.isSome(issuer) and issuer != ?c.issuer) {
            return { exists = false; status = false; metadata = null };
          };
          let status = getStatus(c.statusListId, c.statusIndex);
          let metadata : CredentialMetadata = {
            subject = c.subject;
            issuer = c.issuer;
            type_ = c.type_;
            schema = c.schema;
            issuedAt = c.issuedAt;
            expiresAt = c.expiresAt;
            statusIndex = c.statusIndex;
            statusListId = c.statusListId;
          };
          return { exists = true; status; metadata = ?metadata };
        }
      }
    }
  }
};

/// Candid: Principal <-> DID mapping and vetKeyHandle
public func linkDID(principal: Principal, did: Text, vetKeyHandle: ?Text) : async () {
  didMappings.put(principal, { did; vetKeyHandle });
  principalByDID.put(did, principal);
  emitEvent("linkDID", Principal.toText(principal) # ":" # did);
};

/// Candid: Unlink DID for a principal
public func unlinkDID(principal: Principal) : async () {
  let mappingOpt = didMappings.get(principal);
  switch (mappingOpt) {
    case null { return; };
    case (?mapping) {
      principalByDID.delete(mapping.did);
      didMappings.delete(principal);
      emitEvent("unlinkDID", Principal.toText(principal) # ":" # mapping.did);
    }
  }
};

/// Candid: Get DID mapping for a principal
public query func getDID(principal: Principal) : async ?DIDMapping {
  didMappings.get(principal)
};

/// Candid: Get principal for a DID
public query func getPrincipalByDID(did: Text) : async ?Principal {
  principalByDID.get(did)
};

/////////////////////////////
// Certified Data/Status List 2021 endpoints

/// Candid: Get certified status with certificate blob (mock, in real code use IC certified_data API)
public query func getCertifiedStatus(listId: StatusListId, index: Nat) : async CertifiedStatus {
  // In production, use certified_data API to sign the status value
  let status = getStatus(listId, index);
  let certificate: Blob = Blob.fromArray([]);
  { status; certificate }
};

/// Candid: Get the latest certification certificate (mock)
public query func getCertificate() : async Blob {
  Blob.fromArray([]);
};

/// Candid: Get the current root hash of status lists (mock)
public query func rootHash() : async Blob {
  Blob.fromArray([]);
};

/////////////////////////////
// Pre/Post Upgrade

system func preupgrade() {
  // Data is stable so no special handling needed
  emitEvent("preupgrade", "");
};

system func postupgrade() {
  emitEvent("postupgrade", "");
};

/////////////////////////////
// End of Canister