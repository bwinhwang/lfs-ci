#!/bin/bash

usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION() {

    local branch=$(getConfig LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch)
    mustHaveValue "${branch}" "branch name"
    # from subversion.sh
    uploadToSubversion "${releaseDirectory}/os" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"

    return
}
