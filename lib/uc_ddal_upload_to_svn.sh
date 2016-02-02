#!/bin/bash

## @fn      usecase_DDAL_UPLOAD_TO_SVN()
#  @brief   upload ddal from git to svn
#  @warning this usecase can be disabled on 1st of March 2016
#           => hardcoded path names, no config, also no ut
#  @param   <none>
#  @return  <none>
usecase_DDAL_UPLOAD_TO_SVN() {

    # git clone is done by jenkins, into $WORKSPACE/src/

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local svnUrl=https://svne1.access.nsn.com/isource/svnroot/BTS_SC_LFS
    local svnPath=/os/trunk/fsmr3/src-fsmifdd/src/include

    execute rsync -a --exclude=.git ${WORKSPACE}/src ${workspace}

    uploadToSubversion ${workspace} ${svnUrl} ${svnPath} 

    return 0
}

