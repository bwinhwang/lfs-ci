#!/bin/bash

[[ -z ${LFS_CI_SOURCE_release}    ]] && source ${LFS_CI_ROOT}/lib/release.sh
[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh

## @fn      usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION()
#  @brief   upload the release to subversion
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION() {
    mustBePreparedForReleaseTask

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME

    local tagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${tagName}
    mustExistDirectory ${releaseDirectory}

    local svnReposUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url -t tagName:${tagName})
    mustHaveValue "${svnReposUrl}" "svn repos url"

    local branchName=$(getConfig LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch)
    mustHaveValue "${branchName}" "branch name"

    info "upload local path ${pathToUpload} to ${branch} as ${tagName}"

    uploadToSubversion ${releaseDirectory}/os              \
                       ${svnReposUrl}                      \
                       os/branches/${branchName}           \
                       tags/${tagName}                     \
                       "upload of new lfs build ${tagName}"

    createArtifactArchive

    return 0
}
