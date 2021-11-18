#!/bin/bash


# set -x

filename=testfile.txt

fileext=$(echo ${filename} | cut -d'.' -f2)

# create a 20MB file
seq 1000000 | head -c 20000 > ${filename}

mimetype="text/plain"


storage_id=$(dfx canister id storage)

# dfx canister call $storage_id deleteAllBuckets

balance=$(dfx canister call $storage_id wallet_balance | cut -d'(' -f2 | cut -d' ' -f1)

if [[ $balance == 0 ]]; then
    dfx wallet send $storage_id 1000000000000
fi

filesize=$(($(wc -c $filename | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1) ))

max_payload_size=1000

num_chunks=$(( filesize/max_payload_size + 1 ))

result=$(dfx canister call ${storage_id} putFileInfo "(record {name=\"$filename\"; createdAt=$(date +%s); size=$filesize; chunkCount=$num_chunks; filetype=\"$mimetype\";contentDisposition=\"attachment;filename='$filename'\"})")

fileId=$(echo $result | xargs | cut -d';' -f2 | xargs | cut -d' ' -f3)

echo "fileId is $fileId"

# great! Now let's upload our chunk(s)


# result=$(dfx canister call ${storage_id} putFileChunk "(\"$fileId\", 1:nat, blob \"$chunk\")")
# debug
i=1
for i in $(seq $num_chunks); do
    chunk=$(dd if=$filename ibs=$max_payload_size skip=$(( $i - 1 )) count=1)
    result=$(dfx canister call ${storage_id} putFileChunk "(\"$fileId\", $i:nat, blob \"$chunk\")")
    bucketId=$(echo ${result} | cut -d'"' -f2)
done

# let's try to download our chunk with a canister call
dfx canister call ${storage_id} getFileChunk "(\"${fileId}\", 1:nat, principal \"${bucketId}\")"

# lets now try to download our chunk with  an http call

result=$(curl -v "http://127.0.0.1:8000/storage?fileId=$fileId&canisterId=$bucketId")

[[ $result == $(cat testfile.txt) ]] && echo "test passed" || echo "test failed"

# set +x