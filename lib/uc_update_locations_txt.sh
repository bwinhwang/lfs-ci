#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh

# job name: ADMIN_-_update_locations_txt

## @fn      usecase_UPDATE_LOCATIONS_TXT()
#  @brief   update the locations.txt file in os/trunk/bldtools/ in svn
#  @details content of the file is comming from database
#  @param   <none>
#  @return  <none>
usecase_UPDATE_LOCATIONS_TXT() {
    requiredParameters WORKSPACE

    local svnRepos=$(getConfig lfsSourceRepos)
    mustHaveValue "${svnRepos}" "svn repos"

    svnCheckout ${svnRepos}/os/trunk/bldtools/ ${WORKSPACE}/workspace
    mustExistFile ${WORKSPACE}/workspace/locations.txt

    execute -n ${LFS_CI_ROOT}/bin/getLocationsText > ${WORKSPACE}/workspace/locations.txt

    local commitComment=${WORKSPACE}/commitComment
    echo "update locations.txt" > ${commitComment}

    svnDiff ${WORKSPACE}/workspace/locations.txt
    svnCommit -F ${commitComment} ${WORKSPACE}/workspace/locations.txt

    info "updated locations.txt"

    return
}

