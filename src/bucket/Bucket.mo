import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Trie "mo:base/Trie";
import TrieMap "mo:base/TrieMap";
import Blob "mo:base/Blob";

actor class Bucket () = this {
  public type StreamingCallbackToken = {
    key : Text;
    content_encoding : Text;
    index : Nat; //starts at 1
    sha256: ?[Nat8];
  };

  public type StreamingCallbackHttpResponse = {
    token : ?StreamingCallbackToken;
    body : Blob;
  };

  public type StreamingCallback = query StreamingCallbackToken  -> async StreamingCallbackHttpResponse;


  public type StreamingStrategy = {
    #Callback: {
      token : StreamingCallbackToken;
      callback : StreamingCallback
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

  public query func streamingCallback(token:StreamingCallbackToken): async StreamingCallbackHttpResponse {
      let next_index = token.index+1;
      return switch(next_index) {
        case 5 {
            {
                body="_lastchunk";
                token = null;
            }
        };
        case _ {
        {
            token = ?{
                content_encoding = token.content_encoding;
                index = next_index;
                key = token.key;
                sha256 = null
            };
            body="_middlechunk_";
        };
      };
    };
  };

  public query func http_request(req: HttpRequest) : async HttpResponse {
      return {
          status_code=200;
          headers=[("Content-Type","text/plain"),("Content-Disposition","inline"),("Transfer-Encoding","chunked")];
          body="firstchunk_";
          streaming_strategy=?#Callback({
              token = {
                  content_encoding="gzip";
                  key="a";
                  index=1;
                  sha256=null;
              };
              callback = streamingCallback;
          });
      };
  };
};
