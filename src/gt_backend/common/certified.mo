// Certified Key-Value Store with Merkle-like root, stable storage, and certificate helpers
import CertifiedData "mo:base/CertifiedData";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

actor CertifiedKV {

  stable var kv_stable : [(Blob, Blob)] = [];
  var kv : HashMap.HashMap<Blob, Blob> = HashMap.HashMap(64, Blob.equal, Blob.hash);

  stable var root_stable : Blob = Blob.fromArray([]);

  // Helper: recompute root after each mutation
  private func recompute_root() : Blob {
    // Merkle-ish: hash of sorted (key, value) digests
    let entries = Iter.toArray(kv.entries());
    let digests = Array.map<(Blob, Blob), Blob>(entries, func((k, v)) {
      Hash.hash(Blob.concat(k, v));
    });
    let sorted = Array.sort<Blob>(digests, Blob.compare);
    let root = Hash.hash(Blob.concat(Array.flatten<Blob>(sorted)));
    root
  };

  // Set key->value, update root, set CertifiedData
  public shared({caller}) func set_kv(key : Blob, value : Blob) : async () {
    kv.put(key, value);
    let root = recompute_root();
    root_stable := root;
    CertifiedData.set(root);
  };

  // Delete key, update root, set CertifiedData
  public shared({caller}) func delete_kv(key : Blob) : async () {
    kv.delete(key);
    let root = recompute_root();
    root_stable := root;
    CertifiedData.set(root);
  };

  // Get debug root
  public query func get_root() : async Blob {
    root_stable
  };

  // Get certificate (can be null if not certified)
  public query func get_certificate() : async ?Blob {
    CertifiedData.getCertificate()
  };

  // Internal get (not public)
  private func get_kv(key : Blob) : ?Blob {
    kv.get(key)
  };

  // Preupgrade: persist kv and root
  system func preupgrade() {
    kv_stable := Iter.toArray(kv.entries());
    root_stable := recompute_root();
  };

  // Postupgrade: restore kv from stable var, recompute root
  system func postupgrade() {
    kv := HashMap.HashMap(64, Blob.equal, Blob.hash);
    for ((k, v) in kv_stable.vals()) {
      kv.put(k, v);
    };
    root_stable := recompute_root();
    CertifiedData.set(root_stable);
  };

}