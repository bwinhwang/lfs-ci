#!/bin/bash

[[ -z ${LFS_CI_SOURCE_release}      ]] && source ${LFS_CI_ROOT}/lib/release.sh
[[ -z ${LFS_CI_SOURCE_workflowtool} ]] && source ${LFS_CI_ROOT}/lib/workflowtool.sh

## @fn      usecase_LFS_RELEASE_PRE_RELEASE_CHECKS()
#  @brief   run some pre release checks
#  @details checks, if the release can be released or not
#           this is an early exit, if there is a major problem
#  @todo    extend this tests / checks!
#  @param   <none>
#  @return  <none>
#  @throws  raise an error, if there is a major problem with the release
usecase_LFS_RELEASE_PRE_RELEASE_CHECKS() {
    mustBePreparedForReleaseTask

    requiredParameters LFS_PROD_RELEASE_PREVIOUS_TAG_NAME LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL

    local canCreateReleaseInWorkflowTool=$(getConfig LFS_CI_uc_release_can_create_release_in_wft)

    if [[ ! ${canCreateReleaseInWorkflowTool} ]] ; then
        warning "creating release in WFT is disabled via config"
        return
    fi

    if ! existsBaselineInWorkflowTool ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} ; then
        fatal "previous Version ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} does not exist in WFT"
    fi

    if [[ $(getProductNameFromJobName) =~ LFS ]] ; then
        if ! existsBaselineInWorkflowTool ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL} ; then
            fatal "previous Release Version ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL} does not exist in WFT"
        fi                
    fi
    
    return
}

