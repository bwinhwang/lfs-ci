#!/bin/bash

## @fn      createReleaseTag()
#  @brief   create the release tag
#  @details the release tag / branch just contains a svn:externals with two externals to sdk and lfs_os tag
#  @param   <none>
#  @return  <none>
createReleaseTag() {

    mustBePreparedForReleaseTask

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName 

    # get os label
    local osLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    local osReleaseLabelName=$(sed "s/_LFS_OS_/_LFS_REL_/" <<< ${osLabelName} )
    mustHaveValue "${osLabelName}" "no os label name"

    # check for branch
    local svnUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url)
    mustHaveValue "${svnUrl}" "svn url"

    local svnRepoName=$(getConfig LFS_PROD_svn_delivery_repos_name -t tagName:${osLabelName})
    mustHaveValue "${svnRepoName}" "svn url"

    local svnCommitMessagePrefix=$(getConfig LFS_PROD_uc_release_svn_message_prefix)
    mustHaveValue "${svnCommitMessagePrefix}" "svn commit message"

    local branch=$(getBranchName)
    mustHaveBranchName

    # get sdk label
    componentsFile=${workspace}/bld/bld-externalComponents-summary/externalComponents   
    mustExistFile ${componentsFile}

    local sdk2=$(getConfig sdk2 -f ${componentsFile})
    local sdk3=$(getConfig sdk3 -f ${componentsFile})
    local sdk=$(getConfig sdk -f ${componentsFile})

    info "using sdk2 ${sdk2}"
    info "using sdk3 ${sdk3}"
    info "using sdk  ${sdk}"
    info "using lfs os ${osLabelName}"
    info "using lfs rel ${osReleaseLabelName}"

    # check for the branch
    _mustHaveBranchInSubversion

    # update svn:externals
    _createReleaseTag_setSvnExternals

    # make a tag
    _createReleaseTag

    info "tag created."
    return
}

_mustHaveBranchInSubversion() {
    info "svn repos url is ${svnUrl}/branches/${branch}"
    mustExistBranchInSubversion ${svnUrl} tags 
    mustExistBranchInSubversion ${svnUrl} branches 
    shouldNotExistsInSubversion ${svnUrl}/tags/ "${osReleaseLabelName}"

    if ! existsInSubversion ${svnUrl}/branches ${branch} ; then
        local logMessage=$(createTempFile)
        echo "${svnCommitMessagePrefix} : creating a new branch ${branch}" > ${logMessage}
        svnMkdir -F ${logMessage} ${svnUrl}/branches/${branch} 
    fi
}
_createReleaseTag_setSvnExternals() {
    local svnExternalsFile=$(createTempFile)
    echo "/isource/svnroot/${svnRepoName}/os/tags/${osLabelName} os " >> ${svnExternalsFile}

    local sdkExternalLine=$(getConfig LFS_uc_release_create_release_tag_sdk_external_line -t sdk:${sdk} -t sdk2:${sdk2} -t sdk3:${sdk3})
    mustHaveValue "${sdkExternalLine}" "sdk external line"
    echo "${sdkExternalLine}" >> ${svnExternalsFile}
    info "updating svn:externals"
    svnCheckout --ignore-externals ${svnUrl}/branches/${branch} ${workspace}/svn

    cd ${workspace}/svn
    svnPropSet svn:externals -F ${svnExternalsFile} .
    local logMessage=$(createTempFile)
    echo "${svnCommitMessagePrefix} : updating svn:externals for ${osReleaseLabelName}" > ${logMessage}
    svnCommit -F ${logMessage} .
}

_createReleaseTag() {

    local canCreateReleaseTag=$(getConfig LFS_CI_uc_release_can_create_release_tag)

    # make a tag
    info "create tag ${osReleaseLabelName}"
    if [[ ${canCreateReleaseTag} ]] ; then
        local logMessage=$(createTempFile)
        echo "${svnCommitMessagePrefix} : create new tag ${osReleaseLabelName}" > ${logMessage}
        svnCopy -F ${logMessage} ${svnUrl}/branches/${branch} ${svnUrl}/tags/${osReleaseLabelName}
    else
        warning "creating the release tag is disabled in config"
    fi

    return
}
