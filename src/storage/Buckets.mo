import Types "./Types";
import Random "mo:base/Random";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Prim "mo:prim";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Nat16 "mo:base/Nat16";
import TrieMap "mo:base/TrieMap";

actor class Bucket () = this {

  type FileId = Types.FileId;
  type FileInfo = Types.FileInfo;
  type FileData = Types.FileData;
  type ChunkId = Types.ChunkId;
  type ChunkData = Types.ChunkData;
  type State = Types.State;
  type StableState = Types.StableState;
  type HttpRequest = Types.HttpRequest;
  type HttpResponse = Types.HttpResponse;
  type StreamingCallbackToken = Types.StreamingCallbackToken;
  type StreamingCallbackResponse = Types.StreamingCallbackResponse;
  type StreamingStrategy = Types.StreamingStrategy;

  private func deserializeState(s:StableState):State {
    {
      files = TrieMap.fromEntries<FileId, FileData>(
        Iter.fromArray<(FileId, FileData)>(
          s.files
        ),
        Text.equal,
        Text.hash
      );
      chunks = TrieMap.fromEntries<ChunkId, ChunkData>(
        Iter.fromArray<(ChunkId, ChunkData)>(
          s.chunks,
        ),
        Text.equal,
        Text.hash
      );
    }
  };

  private func serializeState(s:State):StableState {
    {
      files = Iter.toArray(s.files.entries());
      chunks = Iter.toArray(s.chunks.entries());
    }
  };

  stable var stableState:StableState = {
    files = [];
    chunks = [];
  };

  let state:State = deserializeState(stableState);

  system func preupgrade () {
    stableState := serializeState(state);
  };

  system func postupgrade () {
    stableState := {
      files = [];
      chunks = [];
    };
  };

  let limit = 20_000_000_000_000;

  public func getSize(): async Nat {
    Debug.print("canister balance: " # Nat.toText(Cycles.balance()));
    Prim.rts_memory_size();
  };
  // consume 1 byte of entrypy
  func getrByte(f : Random.Finite) : ? Nat8 {
    do ? {
      f.byte()!
    };
  };
  // append 2 bytes of entropy to the name
  // https://sdk.dfinity.org/docs/base-libraries/random
  public func generateRandom(name: Text): async Text {
    var n : Text = name;
    let entropy = await Random.blob(); // get initial entropy
    var f = Random.Finite(entropy);
    let count : Nat = 2;
    var i = 1;
    label l loop {
      if (i >= count) break l;
      let b = getrByte(f);
      switch (b) {
        case (?b) { n := n # Nat8.toText(b); i += 1 };
        case null { // not enough entropy
          Debug.print("need more entropy...");
          let entropy = await Random.blob(); // get more entropy
          f := Random.Finite(entropy);
        };
      };
      
    };
    
    n
  };

  func createFileInfo(fileId: Text, ownerId:Principal, fi: FileInfo) : ?FileId {
          switch (state.files.get(fileId)) {
              case (?_) { /* error -- ID already taken. */ null }; 
              case null { /* ok, not taken yet. */
                  Debug.print("id is..." # debug_show(fileId));   
                  state.files.put(fileId,
                    {
                        fileId = fileId;
                        cid = ownerId;
                        name = fi.name;
                        createdAt = fi.createdAt;
                        uploadedAt = Time.now();
                        chunkCount = fi.chunkCount;
                        size = fi.size ;
                        filetype = fi.filetype;
                        contentDisposition = fi.contentDisposition;
                    }
                  );
                  ?fileId
              };
          }
  };

  public shared (msg) func putFile(fi: FileInfo) : async ?FileId {
    do ? {
      // append 2 bytes of entropy to the name
      let fileId = await generateRandom(fi.name);
      createFileInfo(fileId, msg.caller, fi)!;
    }
  };

  func chunkId(fileId : FileId, chunkNum : Nat) : ChunkId {
      fileId # Nat.toText(chunkNum)
  };
  // add chunks 
  // the structure for storing blob chunks is to unse name + chunk num eg: 123a1, 123a2 etc
  public func putChunk(fileId : FileId, chunkNum : Nat, chunkData : Blob) : async ?() {
    do ? {
      Debug.print("generated chunk id is " # debug_show(chunkId(fileId, chunkNum)) # " from "  #   debug_show(fileId) # " and " # debug_show(chunkNum)  #"  and chunk size..." # debug_show(Blob.toArray(chunkData).size()) );
      state.chunks.put(chunkId(fileId, chunkNum), chunkData);
    }
  };

  func getFileInfoData(fileId : FileId) : ?FileData {
      do ? {
          let v = state.files.get(fileId)!;
            {
            fileId = v.fileId;
            cid = v.cid;
            name = v.name;
            size = v.size;
            chunkCount = v.chunkCount;
            filetype = v.filetype;
            createdAt = v.createdAt;
            uploadedAt = v.uploadedAt;
            contentDisposition = v.contentDisposition;
          }
      }
  };

  public query func getFileInfo(fileId : FileId) : async ?FileData {
    do ? {
      getFileInfoData(fileId)!
    }
  };

  public query func getChunks(fileId : FileId, chunkNum: Nat) : async ?Blob {
      state.chunks.get(chunkId(fileId, chunkNum))
  };

  public func delChunks(fileId : FileId, chunkNum : Nat) : async () {
        state.chunks.delete(chunkId(fileId, chunkNum));
  };

  public func delFileInfo(fileId : FileId) : async () {
      state.files.delete(fileId);
  };

  public query func getInfo() : async [FileData] {
    let b = Buffer.Buffer<FileData>(0);
    let _ = do ? {
      for ((f, _) in state.files.entries()) {
        b.add(getFileInfoData(f)!)
      };
    };
    b.toArray()
  };

  public func wallet_receive() : async { accepted: Nat64 } {
    let available = Cycles.available();
    let accepted = Cycles.accept(Nat.min(available, limit));
    { accepted = Nat64.fromNat(accepted) };
  };

  public func wallet_balance() : async Nat {
    return Cycles.balance();
  };

  // To do: https://github.com/DepartureLabsIC/non-fungible-token/blob/1c183f38e2eea978ff0332cf6ce9d95b8ac1b43d/src/http.mo


  public query func streamingCallback(token:StreamingCallbackToken): async StreamingCallbackResponse {
    Debug.print("Sending chunk " # debug_show(token.key) # debug_show(token.index));
    let body:Blob = switch(state.chunks.get(chunkId(token.key, token.index))) {
      case (?b) b;
      case (null) "404 Not Found";
    };
    let next_token:?StreamingCallbackToken = switch(state.chunks.get(chunkId(token.key, token.index+1))){
      case (?nextbody) ?{
        content_encoding=token.content_encoding;
        key = token.key;
        index = token.index+1;
        sha256 = null;
      };
      case (null) null;
    };

    {
      body=body;
      token=next_token;
    };
  };


  public query func http_request(req: HttpRequest) : async HttpResponse {
    // url format: raw.ic0.app/storage?canisterId=<bucketId>&fileId=<fileId>=<fileId>
    // http://127.0.0.1:8000/storage?canisterId=<bucketId>&fileId=testfile.txt25
    var _status_code:Nat16=404;
    var _headers = [("Content-Type","text/html"), ("Content-Disposition","inline")];
    var _body:Blob = "404 Not Found";
    var _streaming_strategy:?StreamingStrategy = null;
    let _ = do ? {
      let storageParams:Text = Text.stripStart(req.url, #text("/storage?"))!;
      let fields:Iter.Iter<Text> = Text.split(storageParams, #text("&"));
      var fileId:?FileId=null;
      var chunkNum:Nat=1;
      for (field:Text in fields){
        let kv:[Text] = Iter.toArray<Text>(Text.split(field,#text("=")));
        if (kv[0]=="fileId"){
          fileId:=?kv[1];
        }
      };
      let fileData:FileData = getFileInfoData(fileId!)!;
      // Debug.print("FileData: " # debug_show(fileData));
      _body := state.chunks.get(chunkId(fileId!, chunkNum))!;
      _headers := [
        ("Content-Type",fileData.filetype),
        // ("Content-Length",Nat.toText(fileData.size-1)),
        ("Transfer-Encoding", "chunked"),
        ("Content-Disposition",fileData.contentDisposition)
      ];
      _status_code:=200;
      if (fileData.chunkCount > 1){
        _streaming_strategy := ?#Callback({
          token = {
            content_encoding="gzip";
            key=fileId!;
            index=chunkNum; //starts at 1
            sha256=null;
          };
          callback = streamingCallback;
        });
      };

    };
    return {
      status_code=_status_code;
      headers=_headers;
      body=_body;
      streaming_strategy=_streaming_strategy;
    };
  };

};