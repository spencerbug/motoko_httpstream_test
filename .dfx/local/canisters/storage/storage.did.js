export const idlFactory = ({ IDL }) => {
  const FileId__1 = IDL.Text;
  const Timestamp = IDL.Int;
  const FileId = IDL.Text;
  const FileData = IDL.Record({
    'cid' : IDL.Principal,
    'contentDisposition' : IDL.Text,
    'name' : IDL.Text,
    'createdAt' : Timestamp,
    'size' : IDL.Nat,
    'filetype' : IDL.Text,
    'fileId' : FileId,
    'chunkCount' : IDL.Nat,
    'uploadedAt' : Timestamp,
  });
  const FileInfo = IDL.Record({
    'contentDisposition' : IDL.Text,
    'name' : IDL.Text,
    'createdAt' : Timestamp,
    'size' : IDL.Nat,
    'filetype' : IDL.Text,
    'chunkCount' : IDL.Nat,
  });
  const FileUploadResult = IDL.Record({
    'bucketId' : IDL.Principal,
    'fileId' : FileId,
  });
  const Container = IDL.Service({
    'delFileChunk' : IDL.Func(
        [FileId__1, IDL.Nat, IDL.Principal],
        [IDL.Opt(IDL.Null)],
        [],
      ),
    'delFileInfo' : IDL.Func(
        [FileId__1, IDL.Principal],
        [IDL.Opt(IDL.Null)],
        [],
      ),
    'getAllFiles' : IDL.Func([], [IDL.Vec(FileData)], []),
    'getFileChunk' : IDL.Func(
        [FileId__1, IDL.Nat, IDL.Principal],
        [IDL.Opt(IDL.Vec(IDL.Nat8))],
        [],
      ),
    'getFileInfo' : IDL.Func(
        [FileId__1, IDL.Principal],
        [IDL.Opt(FileData)],
        [],
      ),
    'getStatus' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Principal, IDL.Nat))],
        ['query'],
      ),
    'putFileChunk' : IDL.Func(
        [FileId__1, IDL.Nat, IDL.Vec(IDL.Nat8)],
        [IDL.Principal],
        [],
      ),
    'putFileInfo' : IDL.Func([FileInfo], [IDL.Opt(FileUploadResult)], []),
    'updateStatus' : IDL.Func([], [], []),
    'wallet_balance' : IDL.Func([], [IDL.Nat], []),
    'wallet_receive' : IDL.Func([], [], []),
  });
  return Container;
};
export const init = ({ IDL }) => { return []; };
