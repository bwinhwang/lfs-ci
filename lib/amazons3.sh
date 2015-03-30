#!/bin/bash

s3PutFile() {
    local file=${1}
    mustExistFile ${file}

    local bucket=${2}
    mustHaveValue "${bucket}" "bucket name"

    info "uploading ${file} to ${bucket}"
    execute s3cmd put ${file} ${bucket}
    return
}

s3RemoveFile() {
    local file=${1}
    mustExistFile ${file}
    local bucket=${2}
    mustHaveValue "${bucket}" "bucket name"

    execute s3cmd rm ${file} ${bucket}
    return
}

s3SetAccessPublic() {
    local url=${1}
    mustHaveValue "${url}" "url"
    execute s3cmd --acl-public setacl ${url}
    return
}
