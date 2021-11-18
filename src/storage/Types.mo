import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Trie "mo:base/Trie";
import TrieMap "mo:base/TrieMap";
import Blob "mo:base/Blob";

module {

  public type FileId = Text;
  
  public type Timestamp = Int; // See mo:base/Time and Time.now()

  public type ChunkData = Blob;

  public type ChunkId = Text; 
  

  public type FileInfo = {
    createdAt : Timestamp;
    chunkCount: Nat;    
    name: Text;
    size: Nat;
    filetype: Text;
    contentDisposition: Text;
  }; 

  public type FileData = {
    fileId : FileId;
    cid : Principal;
    uploadedAt : Timestamp;
    createdAt : Timestamp;
    chunkCount: Nat;    
    name: Text;
    size: Nat;
    filetype: Text;
    contentDisposition: Text;
  };

  public type FileUploadResult = {
    bucketId: Principal;
    fileId: FileId;
  };

  public type Service = actor {
    getSize : shared () -> async Nat;
    putFileChunk : shared (FileId, Nat, Blob) -> async ?Principal;
    putFileInfo : shared FileInfo -> async ?FileUploadResult;
    getFileChunk: shared (FileId, Nat, Principal) -> async ?Blob;
    getFileInfo: shared (FileId, Principal) -> async ?FileData;
    delFileChunk : shared (FileId, Nat, Principal) -> async ();
    delFileInfo : shared (FileId, Principal) -> async ();
    getAllFiles : shared () -> async [FileData];
  };

  public type Map<X, Y> = TrieMap.TrieMap<X, Y>;

  public type State = {
      files : Map<FileId, FileData>;
      // all chunks.
      chunks : Map<ChunkId, ChunkData>;
  };

  public type StableState = {
    files: [(FileId, FileData)];
    chunks: [(ChunkId, ChunkData)];
  };

  public func empty () : State {
    let st : State = {
      files = TrieMap.TrieMap<FileId, FileData>(Text.equal, Text.hash);
      chunks = TrieMap.TrieMap<ChunkId, ChunkData>(Text.equal, Text.hash);
    };
    st
  };

  public type StreamingCallbackToken = {
    content_encoding : Text;
    key : Text;
    index : Nat; //starts at 1
    sha256: ?[Nat8];
  };

  public type StreamingCallbackResponse = {
    body : Blob;
    token : ?StreamingCallbackToken;
  };

  public type StreamingCallback = query (StreamingCallbackToken) -> async (StreamingCallbackResponse);


  // streaming strategy is a recursive operation
  /*
  http_request response:
  {
    status_code, 
    headers, 
    body=chunkN,
    streamingStrategy={
      StreamingCallbackToken tokenN,
      callback = (token(N))-> StreamingCallbackResponse {
        Blob body=chunkN+1,
        StreamingCallbackToken tokenN+1|null if last chunk
      }
    }
  }
  
  client in browser will call an http request that effectively calls callback(token(N)), callback(token(N+1)), ...

  */
  public type StreamingStrategy = {
    #Callback: {
      token : StreamingCallbackToken;
      callback : StreamingCallback;
    }
  };

  public type HttpRequest = {
    method: Text;
    url: Text;
    headers: [(Text, Text)];
    body: Blob;
  };
  public type HttpResponse = {
    status_code: Nat16;
    headers: [(Text, Text)];
    body: Blob;
    streaming_strategy : ?StreamingStrategy;
  };

  
}