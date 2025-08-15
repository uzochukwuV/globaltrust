import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Option "mo:base/Option";

actor NFTMock {
  public type NFT = {
    id: Nat;
    owner: Principal;
    frozen: Bool;
    collateralized: Bool;
  };

  var nfts : [NFT] = [];

  public func mint(owner: Principal) : NFT {
    let id = nfts.size();
    let nft = { id = id; owner = owner; frozen = false; collateralized = false };
    nfts := nfts # [nft];
    nft
  };

  public func freeze(id: Nat) : Bool {
    nfts := nfts.map(func(n) = if (n.id == id) { { id = n.id; owner = n.owner; frozen = true; collateralized = n.collateralized } } else n);
    true
  };

  public func collateralize(id: Nat) : Bool {
    nfts := nfts.map(func(n) = if (n.id == id) { { id = n.id; owner = n.owner; frozen = n.frozen; collateralized = true } } else n);
    true
  };

  public func transfer(from: Principal, to: Principal, id: Nat) : Bool {
    switch (nfts.find(func n = n.id == id)) {
      case null { false };
      case (?n) {
        if (n.frozen or n.collateralized or n.owner != from) { false }
        else {
          nfts := nfts.map(func(nft) = if (nft.id == id) { { id = id; owner = to; frozen = nft.frozen; collateralized = nft.collateralized } } else nft);
          true
        }
      }
    }
  }
};

actor {
  let alice = Principal.fromText("aaaaa-aa");
  let bob = Principal.fromText("bbbbb-aa");
  let nftmod = NFTMock;

  public func main() : async () {
    Debug.print("NFT: mint/freeze/collateralize/transfer blocking");

    let nft = nftmod.mint(alice);
    assert nftmod.transfer(alice, bob, nft.id);

    nftmod.freeze(nft.id);
    assert not nftmod.transfer(bob, alice, nft.id);

    nftmod.collateralize(nft.id);
    assert not nftmod.transfer(bob, alice, nft.id);

    Debug.print("NFT test passed");
  }
};