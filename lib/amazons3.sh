#!/bin/bash
## @file    amazons3.sh
#  @brief   interface for amazon s3 (Nokia internal s3 storage)
#  @defails see the s3cmd for more details

LFS_CI_SOURCE_amazons3='$Id$'

[[ -z ${LFS_CI_SOURCE_config}   ]] && source ${LFS_CI_ROOT}/lib/config.sh
[[ -z ${LFS_CI_SOURCE_logging}  ]] && source ${LFS_CI_ROOT}/lib/logging.sh
[[ -z ${LFS_CI_SOURCE_commands} ]] && source ${LFS_CI_ROOT}/lib/commands.sh

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

    local s3cmdArgs=$(getConfig TOOL_amazon_s3cmd_args)

    info "uploading ${fileName} to ${bucketName}"
    execute ${s3cmd} ${s3cmdArgs} put ${fileName} ${bucketName}
    return
}

## @fn      s3RemoveFile()
#  @brief   remove a file from the s3 storage
#  @param   {fileName}    name of the file
#  @param   {bucketName}  name of the bucket
#  @return  <none>
s3RemoveFile() {
    local fileName=${1}

    local s3cmd=$(getConfig TOOL_amazon_s3cmd)
    mustExistFile ${s3cmd}
    local s3cmdArgs=$(getConfig TOOL_amazon_s3cmd_args)

    execute ${s3cmd} ${s3cmdArgs} rm ${fileName}
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
    local s3cmdArgs=$(getConfig TOOL_amazon_s3cmd_args)

    execute ${s3cmd} ${s3cmdArgs} --acl-public setacl ${url}
    return
}

## @fn      s3List()
#  @brief   list the content of the s3 bucket
#  @param   {url}    url of the s3 storage (s3://bucket)
#  @return  content
s3List() {
    local url=${1}
    local s3cmd=$(getConfig TOOL_amazon_s3cmd)
    mustExistFile ${s3cmd}
    local s3cmdArgs=$(getConfig TOOL_amazon_s3cmd_args)

    execute -n ${s3cmd} ${s3cmdArgs} ls ${url}
    return
}

