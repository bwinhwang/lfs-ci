#!/bin/bash
#@ @file    amazons3.sh
#  @brief   interface for amazon s3 (Nokia internal s3 storage)
#  @defails see the s3cmd for more details

LFS_CI_SOURCE_amazons3='$Id$'

## @fn      s3PutFile()
#  @brief   put a file in the s3 storage in a defined bucket
#  @param   {fileName}    name of the file
#  @param   {bucketName}  name of the bucket
#  @return  <none>
s3PutFile() {
    local fileName=${1}
    mustExistFile ${fileName}

    local bucketName=${2}
    mustHaveValue "${bucketName}" "bucket name"

    local s3cmd=$(getConfig TOOL_amazon_s3cmd)
    mustExistFile ${s3cmd}

    info "uploading ${fileName} to ${bucketName}"
    execute ${s3cmd} put ${fileName} ${bucketName}
    return
}

## @fn      s3RemoveFile()
#  @brief   remove a file from the s3 storage
#  @param   {fileName}    name of the file
#  @param   {bucketName}  name of the bucket
#  @return  <none>
s3RemoveFile() {
    local fileName=${1}
    mustExistFile ${fileName}

    local bucketName=${2}
    mustHaveValue "${bucketName}" "bucket name"

    local s3cmd=$(getConfig TOOL_amazon_s3cmd)
    mustExistFile ${s3cmd}

    execute ${s3cmd} rm s3://${bucketName}/${fileName}
    return
}

## @fn      s3SetAccessPublic()
#  @brief   get the access level of the url to public - everyone can access the file via http
#  @param   {url}    url 
#  @return  <none>
s3SetAccessPublic() {
    local url=${1}
    mustHaveValue "${url}" "url"

    local s3cmd=$(getConfig TOOL_amazon_s3cmd)
    mustExistFile ${s3cmd}

    execute ${s3cmd} --acl-public setacl ${url}
    return
}

s3List() {
    local url=${1}
    local s3cmd=$(getConfig TOOL_amazon_s3cmd)
    mustExistFile ${s3cmd}

    execute -n ${s3cmd} ls ${url}
    return
}
