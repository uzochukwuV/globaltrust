import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Option "mo:base/Option";

actor CredentialsMock {
  public type Credential = {
    id: Text;
    owner: Principal;
    status: Status;
  };
  public type Status = { #Valid; #Revoked };

  var creds : [Credential] = [];

  public func issue(owner: Principal) : Credential {
    let c = { id = "cred-" # Principal.toText(owner); owner = owner; status = #Valid };
    creds := creds # [c];
    c
  };

  public func revoke(id: Text) : Bool {
    var found = false;
    creds := creds.map(
      func(c) {
        if (c.id == id) {
          found := true;
          { id = c.id; owner = c.owner; status = #Revoked }
        } else { c }
      }
    );
    found
  };

  public func get(id: Text) : ?Credential {
    creds.find(func c = c.id == id)
  };

  public func getCertifiedStatus(id: Text) : Status {
    switch (get(id)) {
      case null { #Revoked }; // Demo: if not found, treat as revoked
      case (?c) { c.status }
    }
  }
};

actor {
  let user = Principal.fromText("aaaaa-aa");
  let cmod = CredentialsMock;

  public func main() : async () {
    Debug.print("Credentials: issue, revoke, get, getCertifiedStatus");

    let cred = cmod.issue(user);
    assert cmod.get(cred.id) != null;
    assert cmod.getCertifiedStatus(cred.id) == #Valid;

    assert cmod.revoke(cred.id);
    assert cmod.getCertifiedStatus(cred.id) == #Revoked;

    Debug.print("Credentials test passed");
  }
};