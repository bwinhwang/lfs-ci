#!/bin/bash

[[ -z ${LFS_CI_SOURCE_release} ]] && source ${LFS_CI_ROOT}/lib/release.sh

## @fn      usecase_LFS_RELEASE_CREATE_RELEASE_TAG()
#  @brief   create the release tag
#  @details the release tag / branch just contains a svn:externals with two externals to sdk and lfs_os tag
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_CREATE_RELEASE_TAG() {
    mustBePreparedForReleaseTask

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName 

    # get os label
    info "using build name: ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}"
    info "creating LFS REL: ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}"

    # check for the branch
    _mustHaveBranchInSubversion

    # update svn:externals
    _createReleaseTag_setSvnExternals

    # make a tag
    _createReleaseTag

    info "tag created."
    return
}

## @fn      _mustHaveBranchInSubversion()
#  @brief   ensures, that the branch exists in subversion
#  @param   <none>
#  @return  <none>
_mustHaveBranchInSubversion() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME

    # check for branch
    local svnUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url \
                              -t tagName:LFS_PROD_RELEASE_CURRENT_TAG_NAME)
    mustHaveValue "${svnUrl}" "svn url"

    local branchName=$(getBranchName)
    mustHaveBranchName

    info "svn repos url is ${svnUrl}/branches/${branchName}"
    mustExistBranchInSubversion ${svnUrl} tags 
    mustExistBranchInSubversion ${svnUrl} branches 
    mustExistBranchInSubversion ${svnUrl}/branches/ ${branchName}

    shouldNotExistsInSubversion ${svnUrl}/tags/ ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    return
}

## @fn      _createReleaseTag_setSvnExternals()
#  @brief   create the svn:externals for LFS Release tag
#  @param   <none>
#  @return  <none>
_createReleaseTag_setSvnExternals() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME    \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local branchName=$(getBranchName)
    mustHaveBranchName

    # get os label
    local osLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${osLabelName}" "no os label name"

    local svnUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url \
                              -t tagName:${osLabelName})
    mustHaveValue "${svnUrl}" "svn url"

    local svnRepoName=$(getConfig LFS_PROD_svn_delivery_repos_name \
                                  -t tagName:${osLabelName})
    mustHaveValue "${svnRepoName}" "svn url"

    # get sdk label
    componentsFile=${workspace}/bld/bld-externalComponents-summary/externalComponents   
    mustExistFile ${componentsFile}

    local sdk2=$(getConfig sdk2 -f ${componentsFile})
    local sdk3=$(getConfig sdk3 -f ${componentsFile})
    local sdk=$(getConfig  sdk  -f ${componentsFile})
    local sdkExternalLine=$(getConfig LFS_uc_release_create_release_tag_sdk_external_line -t sdk:${sdk} -t sdk2:${sdk2} -t sdk3:${sdk3})
    mustHaveValue "${sdkExternalLine}" "sdk external line"

    local svnExternalsFile=${workspace}/svnExternals
    echo "/isource/svnroot/${svnRepoName}/os/tags/${osLabelName} os " >> ${svnExternalsFile}
    echo "${sdkExternalLine}" >> ${svnExternalsFile}

    info "updating svn:externals"
    svnCheckout --ignore-externals ${svnUrl}/branches/${branchName} ${workspace}/svn

    svnPropSet svn:externals -F ${svnExternalsFile} ${workspace}/svn/

    info "commiting svn:externals"
    local commitMessage=${workspace}/commitMessage
    local svnCommitMessagePrefix=$(getConfig LFS_PROD_uc_release_svn_message_prefix)
    echo "${svnCommitMessagePrefix} : updating svn:externals for ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}" > ${commitMessage}
    svnCommit -F ${commitMessage} ${workspace}/svn/

    return
}

## @fn      _createReleaseTag()
#  @brief   create the LFS Release tag
#  @param   <none>
#  @return  <none>
_createReleaseTag() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME    \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local branchName=$(getBranchName)
    mustHaveBranchName

    local svnUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url \
                              -t tagName:LFS_PROD_RELEASE_CURRENT_TAG_NAME)
    mustHaveValue "${svnUrl}" "svn url"

    local canCreateReleaseTag=$(getConfig LFS_CI_uc_release_can_create_release_tag)

    info "creating tag ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}"
    if [[ ${canCreateReleaseTag} ]] ; then
        local commitMessage=${workspace}/commitMessage
        local svnCommitMessagePrefix=$(getConfig LFS_PROD_uc_release_svn_message_prefix)
        echo "${svnCommitMessagePrefix} : create new tag ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}" > ${commitMessage}
        svnCopy -F ${commitMessage} ${svnUrl}/branches/${branchName} ${svnUrl}/tags/${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}
    else
        warning "creating the release tag is disabled in config"
    fi

    return
}
