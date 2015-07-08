#!/bin/bash

## @file    uc_admin_cleanup_s3.sh
#   @brief  cleanup all builds from s3 storage, which are older then 3 days

[[ -z ${LFS_CI_SOURCE_amazons3} ]] && source ${LFS_CI_ROOT}/lib/amazons3.sh

## @fn      usecase_ADMIN_CLEANUP_S3()
#  @brief   execute the usecase admin - cleanup s3 storage
#  @param   <none>
#  @return  <none>
usecase_ADMIN_CLEANUP_S3() {
    local bucketName=$(getSubTaskNameFromJobName)
    mustHaveValue "${bucketName}" "bucket name from job_name"
    cleanupS3Storage ${bucketName}
    return
}

## @fn      cleanupS3Storage()
#  @brief   cleanup old builds from s3 storage
#  @param   {bucketName}    name of the bucket
#  @return  <none>
cleanupS3Storage() {
    local bucketName=$1
    mustHaveValue "${bucketName}" "bucket name"

    local daysNotToDelete=$(createTempFile)
    execute -n date +%Y-%m-%d --date="0 days ago"  > ${daysNotToDelete}
    execute -n date +%Y-%m-%d --date="1 days ago" >> ${daysNotToDelete}
    execute -n date +%Y-%m-%d --date="2 days ago" >> ${daysNotToDelete}
    execute -n date +%Y-%m-%d --date="3 days ago" >> ${daysNotToDelete}

    local listToDelete=$(createTempFile)
    for file in $(s3List s3://${bucketName} | grep -v -f ${daysNotToDelete} | cut -d" " -f 4-) ; do
        info "removing ${file} from s3://${bucketName}"
        s3RemoveFile ${file}
    done
    return
}
