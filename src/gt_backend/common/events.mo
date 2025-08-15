// Append-only event log with ring buffer cap and stable storage
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Types "./types";

module {

  public let CAPACITY : Nat = 10_000;

  public type Event = Types.Event;

  stable var events_stable : [Event] = [];
  var events : [Event] = [];
  stable var cursor_stable : Nat = 0;
  var cursor : Nat = 0;

  // Emit (append) event, overwrite oldest if full (ring buffer)
  public func emit(typ : Types.EventType, details : Text) : async () {
    let evt : Event = {
      id       = cursor,
      timestamp= Time.now(),
      actor    = Principal.fromCaller(),
      typ      = typ,
      details  = details
    };

    if (events.size() < CAPACITY) {
      events := Array.append<Event>(events, [evt]);
    } else {
      let slot = cursor % CAPACITY;
      events[slot] := evt;
    };

    cursor += 1;
  };

  // Query: latest n events (most recent first)
  public query func latest(n : Nat) : async [Event] {
    let total = events.size();
    let res_n = if (n > total) { total } else { n };
    Array.reverse<Array.slice<Event>>(events, total - res_n, res_n)
  };

  // Query: by type, most recent n
  public query func byType(typ : Types.EventType, n : Nat) : async [Event] {
    var found : [Event] = [];
    label search for (evt in Array.reverse(events).vals()) {
      if (evt.typ == typ) {
        found := Array.append<Event>(found, [evt]);
        if (found.size() >= n) break search;
      }
    };
    found
  };

  // For RBAC: notify wrapper if needed
  public func notify(typ : Types.EventType, details : Text) : async () {
    await emit(typ, details);
  };

  // Upgrade hooks
  system func preupgrade() {
    events_stable := events;
    cursor_stable := cursor;
  };

  system func postupgrade() {
    events := events_stable;
    cursor := cursor_stable;
  };

}