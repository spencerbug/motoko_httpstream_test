import Array "mo:base/Array";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import List "mo:base/List";
import Error "mo:base/Error";
import Types "./Types";
import Buckets "./Buckets";
import IC "./IC";


// Container actor holds all created canisters in a canisters array 
// Use of IC management canister with specified Principal "aaaaa-aa" to update the newly 
// created canisters permissions and settings 
//  https://sdk.dfinity.org/docs/interface-spec/index.html#ic-management-canister
shared ({caller = owner}) actor class Container() = this {

  type Bucket = Buckets.Bucket;
  type Service = Types.Service;
  type FileId = Types.FileId;
  type FileInfo = Types.FileInfo;
  type FileData = Types.FileData;
  type FileUploadResult = Types.FileUploadResult;

  let ic:IC.IC = actor("aaaaa-aa");

// canister info hold an actor reference and the result from rts_memory_size
  type CanisterState<Bucket, Nat> = {
    bucket  : Bucket;
    var size : Nat;
  };

  private stable var stableCanisters: [(Text, Nat)] = [];

  // restore state from memory
  private var canisters = List.fromArray<CanisterState<Bucket, Nat>>(
    Array.map< (Text, Nat), CanisterState<Bucket, Nat>  >(
      stableCanisters,
      func (principalText:Text, _size:Nat): CanisterState<Bucket, Nat> {
        let _bucket:Bucket = actor(principalText);
        {
          bucket=_bucket;
          var size=_size;
        }
      }
    )
  );

  // canister map is a cached way to fetch canisters info
  // this will be only updated when a file is added 
  // restore this from stable memory as well
  private let canisterMap = HashMap.fromIter<Principal, Nat>(
    Iter.map<(Text, Nat), (Principal, Nat)>(
      Iter.fromArray<(Text, Nat)>(stableCanisters),
      func(principalText:Text, size:Nat):(Principal, Nat) {
        (
          Principal.fromText(principalText),
          size
        )
      }
    ),
    100,
    Principal.equal,
    Principal.hash
  );
  
  system func preupgrade() {
    stableCanisters := List.toArray(
      List.map<CanisterState<Bucket, Nat>, (Text, Nat)>(
        canisters,
        func(canisterState:CanisterState<Bucket, Nat>) {
          (
            Principal.toText(Principal.fromActor(canisterState.bucket)),
            canisterState.size
          )
        }
      )
    );
  };

  system func postupgrade() {
    stableCanisters := [];
  };


  // this is the number I've found to work well in my tests
  // until canister updates slow down 
  //From Claudio:  Motoko has a new compacting gc that you can select to access more than 2 GB, but it might not let you
  // do that yet in practice because the cost of collecting all that memory is too high for a single message.
  // GC needs to be made incremental too. We are working on that.
  // https://forum.dfinity.org/t/calling-arguments-from-motoko/5164/13
  private let threshold = 2147483648; //  ~2GB
  // private let threshold = 50715200; // Testing numbers ~ 50mb

  // each created canister will receive 1T cycles
  // value is set only for demo purposes please update accordingly 
  private let cycleShare = 1_000_000_000_000;



  // dynamically install a new Bucket
  func newEmptyBucket(): async Bucket {
    Cycles.add(cycleShare);
    let b = await Buckets.Bucket();
    let _ = await updateCanister(b); // update canister permissions and settings
    let s = await b.getSize();
    Debug.print("new canister principal is " # debug_show(Principal.toText(Principal.fromActor(b))) );
    Debug.print("initial size is " # debug_show(s));
    let _ = canisterMap.put(Principal.fromActor(b), threshold);
     var v : CanisterState<Bucket, Nat> = {
         bucket = b;
         var size = s;
    };
    canisters := List.push<CanisterState<Bucket, Nat>>(v, canisters);
  
    b;
  };

  // check if there's an empty bucket we can use
  // create a new one in case none's available or have enough space 
  func getEmptyBucket(s : ?Nat): async Bucket {
    let fs: Nat = switch (s) {
      case null { 0 };
      case (?s) { s }
    };
    let cs:?CanisterState<Bucket, Nat> = List.find<CanisterState<Bucket, Nat>>(canisters,
      func(_cs:CanisterState<Bucket, Nat>):Bool {
        Debug.print("found canister with principal..." # debug_show(Principal.toText(Principal.fromActor(_cs.bucket))));
        _cs.size + fs < threshold
      }
    );
    let eb : ?Bucket = do ? {
        let c = cs!;
        c.bucket
    };
    let c: Bucket = switch (eb) {
        case null { await newEmptyBucket() };
        case (?eb) { eb };
    };
    c
  };
  // canister memory is set to 4GB and compute allocation to 5 as the purpose 
  // of this canisters is mostly storage
  // set canister owners to the wallet canister and the container canister ie: this
  func updateCanister(a: actor {}) : async () {
    Debug.print("balance before: " # Nat.toText(Cycles.balance()));
    // Cycles.add(Cycles.balance()/2);
    let cid = { canister_id = Principal.fromActor(a)};
    Debug.print("IC status..."  # debug_show(await ic.canister_status(cid)));
    // let cid = await IC.create_canister(  {
    //    settings = ?{controllers = [?(owner)]; compute_allocation = null; memory_allocation = ?(4294967296); freezing_threshold = null; } } );
    
    await (ic.update_settings( {
       canister_id = cid.canister_id; 
       settings = { 
         controllers = ?[owner, Principal.fromActor(this)];
         compute_allocation = null;
        //  memory_allocation = ?4_294_967_296; // 4GB
         memory_allocation = null; // 4GB
         freezing_threshold = ?31_540_000} })
    );
  };

  func asyncIterateList<T>(l:List.List<T>, f : T -> async ()): async () {
    switch (l) {
      case null { () };
      case (?(h, t)) {
        await f(h);
        await asyncIterateList<T>(t,f)
      };
    }
  };

  // go through each canister and check size
  public func updateStatus(): async () {
    await asyncIterateList<CanisterState<Bucket, Nat>>(canisters, func (cs:CanisterState<Bucket, Nat>): async (){
      let s:Nat = await cs.bucket.getSize();
      Debug.print("canister with id: " # debug_show(Principal.toText(Principal.fromActor(cs.bucket))) # " size is " # debug_show(s));
      cs.size := s;
      let _ = updateSize(Principal.fromActor(cs.bucket), s);
    });
  };

  // get canisters status
  // this is cached until a new upload is made
  public query func getStatus() : async [(Principal, Nat)] {
    Iter.toArray<(Principal, Nat)>(canisterMap.entries());
  };

  // update hashmap 
  func updateSize(p: Principal, s: Nat) : () {
    var r = 0;
    if (s < threshold) {
      r := threshold - s;
    };
    let _ = canisterMap.replace(p, r);
  };

  // persist chunks in bucket
  public func putFileChunk(fileId: FileId, chunkNum : Nat, chunkData : Blob) : async Principal {
    let b : Bucket = await getEmptyBucket(?chunkData.size());
    let _ = await b.putChunk(fileId, chunkNum, chunkData);
    return Principal.fromActor(b);
  };

  // save file info, also reserve space in bucket
  public shared(msg) func putFileInfo(fi: FileInfo) : async ?FileUploadResult {
    do ? {
      let b: Bucket = await getEmptyBucket(?fi.size);
      Debug.print("creating file info..." # debug_show(fi));
      let fileId:FileId = (await b.putFile(fi))!;
      {
        bucketId = Principal.fromActor(b);
        fileId = fileId;
      };
    }
  };

  func getBucket(cid: Principal) : ?Bucket {
    let cs:?CanisterState<Bucket, Nat> = List.find<CanisterState<Bucket, Nat>>(canisters,
      func(_cs:CanisterState<Bucket, Nat>):Bool {
        Debug.print("found canister with principal..." # debug_show(Principal.toText(Principal.fromActor(_cs.bucket))));
        Principal.equal(Principal.fromActor(_cs.bucket), cid)
      }
    );
    let eb : ?Bucket = do ? {
      let c = cs!;
      c.bucket;
    };
  };

  // get file chunk 
  public func getFileChunk(fileId : FileId, chunkNum : Nat, cid: Principal) : async ?Blob {
    do ? {
      let b : Bucket = (getBucket(cid))!;
      return await b.getChunks(fileId, chunkNum);
    }   
  };

  // get file info
  public func getFileInfo(fileId : FileId, cid: Principal) : async ?FileData {
    do ? {
      let b : Bucket = (getBucket(cid))!;
      return await b.getFileInfo(fileId);
    }   
  };

    // delete file chunk
  public func delFileChunk(fileId: FileId, chunkNum : Nat, cid: Principal) : async ?() {
      do ? {
          let b : Bucket = (getBucket(cid))!;
          let _ = await b.delChunks(fileId, chunkNum);
      }
  };

  // delete file info
  public func delFileInfo(fileId : FileId, cid: Principal) : async ?() {
      do ? {
        let b : Bucket = (getBucket(cid))!;
        let _ = await b.delFileInfo(fileId);
      }
  };

  // get a list of files from all canisters
  public func getAllFiles() : async [FileData] {
    let buff = Buffer.Buffer<FileData>(0);
    await asyncIterateList<CanisterState<Bucket, Nat>>(
      canisters,
      func (cs:CanisterState<Bucket, Nat>): async (){
        let bi = await cs.bucket.getInfo();
        for (j in Iter.range(0, bi.size() - 1)) {
          buff.add(bi[j])
        };
      }
    );
    buff.toArray()
  };  

  public shared(msg) func wallet_receive() : async () {
    ignore Cycles.accept(Cycles.available());
  };

  public shared(msg) func wallet_balance() : async Nat {
    return Cycles.balance();
  };
};

  