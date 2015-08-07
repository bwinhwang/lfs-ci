#!/bin/bash

[[ -z ${LFS_CI_SOURCE_release} ]] && source ${LFS_CI_ROOT}/lib/release.sh

## @fn      usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION()
#  @brief   upload the release to subversion
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION() {

    mustBePreparedForReleaseTask

    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustExistDirectory ${releaseDirectory}

    uploadToSubversion "${releaseDirectory}/os" 

    return
}
