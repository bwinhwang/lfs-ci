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

    # in git, the changelog.xml is not a xml file. It's a text file.
    copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} ${BUILD_NUMBER} changelog.xml

    uploadToSubversion ${workspace} ${svnUrl} ${svnPath} "" ${WORKSPACE}/changelog.xml

    return 0
}

