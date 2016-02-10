#!/bin/bash

## @fn      usecase_DDAL_UPLOAD_TO_SVN()
#  @brief   upload ddal from git to svn
#  @warning this usecase can be disabled on 1st of March 2016
#  @param   <none>
#  @return  <none>
usecase_DDAL_UPLOAD_TO_SVN() {

    # git clone is done by jenkins, into $WORKSPACE/src/

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local svnUrl=$(getConfig DDAL_svn_url)
    local svnPath=$(getConfig DDAL_svn_path)

    execute rsync -a --exclude=.git ${WORKSPACE}/src/. ${workspace}

    uploadToSubversion ${workspace} ${svnUrl} ${svnPath} 

    return 0
}

