#!/bin/bash

uploadToSubversion() {

    requiredParameters WORKSPACE LFS_CI_ROOT

    local pathToUpload=$1
    local branchToUpload=$2

    # locate the workspace / path which should be used to upload the production
    workspace=${WORKSPACE}/upload/${branchToUpload}
    execute mkdir -p ${workspace}
    
    # update the workspace
    if [[ -d ${workspace}/.svn ]] ; then
        execute svn up ${workspace}
    else
        execute svn co ${repos}
    fi

    # "compare" / execute svn_updater and execute the generated script
    local uploadScript=$(createTempFile)
    if ${LFS_CI_ROOT}/bin/svn_updater > ${uploadScript}
        execute bash ${uploadScript}
    else
        error "failed to create svn upload script via svn_updater"
    fi
    # svn commit
    execute svn commit -m "upload for production" 

    return
}

