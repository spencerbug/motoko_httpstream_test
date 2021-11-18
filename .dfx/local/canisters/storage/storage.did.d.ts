import type { Principal } from '@dfinity/principal';
export interface Container {
  'delFileChunk' : (
      arg_0: FileId__1,
      arg_1: bigint,
      arg_2: Principal,
    ) => Promise<[] | [null]>,
  'delFileInfo' : (arg_0: FileId__1, arg_1: Principal) => Promise<[] | [null]>,
  'getAllFiles' : () => Promise<Array<FileData>>,
  'getFileChunk' : (
      arg_0: FileId__1,
      arg_1: bigint,
      arg_2: Principal,
    ) => Promise<[] | [Array<number>]>,
  'getFileInfo' : (arg_0: FileId__1, arg_1: Principal) => Promise<
      [] | [FileData]
    >,
  'getStatus' : () => Promise<Array<[Principal, bigint]>>,
  'putFileChunk' : (
      arg_0: FileId__1,
      arg_1: bigint,
      arg_2: Array<number>,
    ) => Promise<Principal>,
  'putFileInfo' : (arg_0: FileInfo) => Promise<[] | [FileUploadResult]>,
  'updateStatus' : () => Promise<undefined>,
  'wallet_balance' : () => Promise<bigint>,
  'wallet_receive' : () => Promise<undefined>,
}
export interface FileData {
  'cid' : Principal,
  'contentDisposition' : string,
  'name' : string,
  'createdAt' : Timestamp,
  'size' : bigint,
  'filetype' : string,
  'fileId' : FileId,
  'chunkCount' : bigint,
  'uploadedAt' : Timestamp,
}
export type FileId = string;
export type FileId__1 = string;
export interface FileInfo {
  'contentDisposition' : string,
  'name' : string,
  'createdAt' : Timestamp,
  'size' : bigint,
  'filetype' : string,
  'chunkCount' : bigint,
}
export interface FileUploadResult { 'bucketId' : Principal, 'fileId' : FileId }
export type Timestamp = bigint;
export interface _SERVICE extends Container {}
