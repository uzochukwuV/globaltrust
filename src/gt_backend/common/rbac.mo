// Role-Based Access Control (RBAC) module
import Prim "mo:prim";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Set "mo:base/Set";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Events "./events";
import Types "./types";

actor class RBAC(init_admin: ?Principal) = this {

  // Role and Principal types
  public type Role = Types.Role;
  public type Principal = Principal;

  // Stable storage for RBAC: Principal -> Set<Role>
  stable var rbac_data_stable : [(Principal, [Role])] = [];
  var rbac_data : HashMap.HashMap<Principal, Set.Set<Role>> = HashMap.HashMap(32, Principal.equal, Principal.hash);

  // Stable storage for admin principal
  stable var admin_principal_stable : ?Principal = null;

  // Stable storage for DAO principal(s)
  stable var dao_principals_stable : [Principal] = [];

  // Bootstrap: set admin principal at install (fallback: caller)
  let bootstrap_admin : Principal = switch(init_admin) {
    case (?p) { p };
    case null  { Principal.fromActor(this) }; // fallback: installing principal
  };

  // Event emission via events.mo
  private func emit_event(typ : Types.EventType, details : Text) : async () {
    ignore Events.emit(typ, details);
  };

  // RBAC core logic

  // Only Admin or DAO can grant/revoke sensitive roles.
  private func is_admin_or_dao(caller : Principal) : Bool {
    let is_admin = Option.get(admin_principal_stable, bootstrap_admin) == caller;
    let is_dao = Array.find<Principal>(dao_principals_stable, func(p) { p == caller }) != null;
    is_admin or is_dao
  };

  // Grant a role to a principal
  public shared({caller}) func grantRole(role : Role, principal : Principal) : async Bool {
    if (not is_admin_or_dao(caller)) {
      await emit_event(#RBACDenied, "grantRole unauthorized");
      return false;
    };

    var roles = switch (rbac_data.get(principal)) {
      case null { Set.new<Role>() };
      case (?set) { set };
    };

    let added = Set.put<Role>(roles, role);
    rbac_data.put(principal, roles);
    await emit_event(#RoleGranted, "Role " # debug_show(role) # " granted to " # Principal.toText(principal));
    return added;
  };

  // Revoke a role from a principal
  public shared({caller}) func revokeRole(role : Role, principal : Principal) : async Bool {
    if (not is_admin_or_dao(caller)) {
      await emit_event(#RBACDenied, "revokeRole unauthorized");
      return false;
    };

    let roles_opt = rbac_data.get(principal);
    switch(roles_opt) {
      case null { return false };
      case (?roles) {
        let removed = Set.remove<Role>(roles, role);
        if (Set.size(roles) == 0) { rbac_data.delete(principal); }
        await emit_event(#RoleRevoked, "Role " # debug_show(role) # " revoked from " # Principal.toText(principal));
        return removed;
      }
    }
  };

  // Check if a principal has a role
  public query func hasRole(role : Role, principal : Principal) : async Bool {
    switch (rbac_data.get(principal)) {
      case null { false };
      case (?roles) { Set.contains<Role>(roles, role) };
    }
  };

  // List all roles for a principal
  public query func getRoles(principal : Principal) : async [Role] {
    switch (rbac_data.get(principal)) {
      case null { [] };
      case (?roles) { Iter.toArray(Set.keys<Role>(roles)) };
    }
  };

  // List all principals for a role
  public query func getPrincipals(role : Role) : async [Principal] {
    Iter.toArray(
      Iter.filter< (Principal, Set.Set<Role>) >(
        rbac_data.entries(),
        func ((principal, roles)) { Set.contains<Role>(roles, role) }
      )
    ).map(func((principal, _)) { principal })
  };

  // Set DAO principal(s)
  public shared({caller}) func setDAOPrincipals(daoPrincipals : [Principal]) : async Bool {
    if (not is_admin_or_dao(caller)) {
      await emit_event(#RBACDenied, "setDAOPrincipals unauthorized");
      return false;
    };
    dao_principals_stable := daoPrincipals;
    await emit_event(#DAOSet, "DAO principals set: " # debug_show(daoPrincipals));
    return true;
  };

  // ---- Upgrade hooks ----

  system func preupgrade() {
    rbac_data_stable := Iter.toArray(
      Iter.map(
        rbac_data.entries(),
        func ((p, roles)) : (Principal, [Role]) {
          (p, Iter.toArray(Set.keys<Role>(roles)))
        }
      )
    );
    admin_principal_stable := Option.get(admin_principal_stable, bootstrap_admin);
    // DAO principals already stored in dao_principals_stable
  };

  system func postupgrade() {
    rbac_data := HashMap.HashMap(32, Principal.equal, Principal.hash);
    for ((p, roles_arr) in rbac_data_stable.vals()) {
      let roles = Set.new<Role>();
      for (r in roles_arr.vals()) { ignore Set.put<Role>(roles, r); };
      rbac_data.put(p, roles);
    };
    // admin_principal_stable and dao_principals_stable restored automatically
  };

}