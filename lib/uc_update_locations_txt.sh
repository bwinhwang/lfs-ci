#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh

# job name: ADMIN_-_update_locations_txt
usecase_UPDATE_LOCATIONS_TXT() {
    requiredParameters WORKSPACE

    local svnRepos=$(getConfig lfsSourceRepos)
    mustHaveValue "${svnRepos}" "svn repos"

    svnCommit ${svnRepos}/os/trunk/bldtools/ ${WORKSPACE}/workspace
    mustExistFile ${WORKSPACE}/workspace/bldtools/locations.txt

    execute -n ${LFS_CI_ROOT}/bin/getLocationsText > ${WORKSPACE}/workspace/bldtools/locations.txt

    local commitComment=${workspace}/commitComment
    echo "update locations.txt" > ${commitComment}

    svnDiff ${WORKSPACE}/workspace/bldtools/locations.txt
    svnCommit -F ${commitComment} ${WORKSPACE}/workspace/bldtools/locations.txt

    info "updated locations.txt"

    return
}

