import Debug "mo:base/Debug";
import Principal "mo:base/Principal";

actor RBACMock {
  type Role = { #Admin; #Issuer; #User };
  var roles : [(Principal, [Role])] = [];

  public func grantRole(user: Principal, role: Role) : Bool {
    switch (roles.find(func ((p, _)) = Principal.equal(p, user))) {
      case null { roles := roles # [(user, [role])]; true };
      case (?(_, rs)) {
        if (rs.contains(role)) { false }
        else {
          roles := roles.map(
            func((p, rs)) = if (Principal.equal(p, user)) (p, rs # [role]) else (p, rs)
          );
          true
        }
      }
    }
  };

  public func revokeRole(user: Principal, role: Role) : Bool {
    switch (roles.find(func ((p, _)) = Principal.equal(p, user))) {
      case null { false };
      case (?(_, rs)) {
        if (not rs.contains(role)) { false }
        else {
          roles := roles.map(
            func((p, rs)) = if (Principal.equal(p, user)) (p, rs.filter(func r = r != role)) else (p, rs)
          );
          true
        }
      }
    }
  };

  public func hasRole(user: Principal, role: Role) : Bool {
    switch (roles.find(func ((p, _)) = Principal.equal(p, user))) {
      case null { false };
      case (?(_, rs)) { rs.contains(role) }
    }
  }
};

actor {
  let p1 = Principal.fromText("aaaaa-aa");
  let rbac = RBACMock;

  public func main() : async () {
    Debug.print("RBAC test: grant, revoke, hasRole");

    assert rbac.grantRole(p1, #Admin);
    assert rbac.hasRole(p1, #Admin);
    assert not rbac.hasRole(p1, #User);

    assert rbac.grantRole(p1, #User);
    assert rbac.hasRole(p1, #User);

    assert rbac.revokeRole(p1, #Admin);
    assert not rbac.hasRole(p1, #Admin);

    Debug.print("RBAC test passed");
  }
};