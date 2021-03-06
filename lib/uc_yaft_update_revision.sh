#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh

# job name: LFS_CI_-_trunk_-_update_yaft_revision

## @fn      usecase_YAFT_UPDATE_REVISION()
#  @brief   run the usecase update yaft revision in src-project/Dependencies 
#  @param   <none>
#  @return  <none>
usecase_YAFT_UPDATE_REVISION() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    export PATH=/opt/subversion/x86_64/1.8.9/bin/:${PATH}

    local locationName=$(getLocationName)
    mustHaveLocationName

    local yaftSvnUrl=$(getConfig LFS_CI_uc_yaft_update_revision_svn_url)
    mustExistInSubversion ${yaftSvnUrl} trunk

    local revision=$(getSvnLastChangedRevision ${yaftSvnUrl}/trunk)
    mustHaveValue "${revision}" "latest yaft revision"

    local commitComment=${WORKSPACE}/commitComment
    echo "update yaft to revision ${revision}" > ${commitComment}

    createBasicWorkspace -l ${locationName} src-project
    execute sed -i -e "s|\(hint *bld/yaft *--revision\).*|\1=${revision}|" \
            ${workspace}/src-project/Dependencies
    svnDiff ${workspace}/src-project/Dependencies
    svnCommit -F ${commitComment} ${workspace}/src-project/Dependencies

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "yaft rev. ${revision}"

    info "updated yaft in Dependencies file to revision ${revision}."

    return
}

