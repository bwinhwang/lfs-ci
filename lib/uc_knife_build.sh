#!/bin/bash
## @file uc_knife_build.sh
#  @brief usecase for create a lfs knife build
#  @details  workflow
# * triggered via WFT 
# * runnins as a Jenkins project in LFS CI
#   - INPUT
#     - name of the requestor of the knife (username, email, real name)
#     - name of the branch in BTS_SC_LFS (opt)
#     - knife.zip (opt)
#     - knife request id (from WFT) (opt)
#     - base of the knife (baseline name)
#   job parameter
#     - KNIFE: knife.tar.gz
#     - BASED_ON: - LFS
#     - 
#   - OUTPUT
#     - location (path on build share), where the LFS production is stored
#     - upload to S3
#
# * create a workspace
#   - based on baseline name
#   - or on branch name from BTS_SC_LFS
#   - we can use the existing createWorkspace function, but we have to
#     fake the revision state file with the baseline name:
#     src-bos <url> <LABEL>
#     src-kernelsources <url> <LABEL>
#     ...
#
# Limitations
#  - only on branches, which are compartible with the new CI
#
# in Jenkins 
# * jobnames
#   - LFS_KNIFE_-_knife_-_Build
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fcmd
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fspc
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_qemu
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r3_-_fsm3_octeon2
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r3_-_qemu_64
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r4_-_fsm4_axm
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r4_-_fsm4_k2
#   - LFS_KNIFE_-_knife_-_Package_-_package
#
# build names
#  - PS_LFS_OS_2015_01_0001 => 15010001
#  - FB_PS_LFS_OS_2015_01_0001 => fb15010001
#  - KNIFE_<id>_PS_LFS_OS_2015_01_0001 => knife<id>15010001
#
# Brain storming
# * we want to use as much code as possible from usecases build and package
# * we should think about to have a own configuation for a knife, which is overwriting the default values
#   (change in Config)
# * workspaces are unique
#   - /var/fpwork/${USER}/lfs-knife-workspaces/knifes.<dateTime>.<requestor>.<knifeId>
# * knife workspaces can be deleted after building (no matter if it is successful or not)

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion}      ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_special_build}   ]] && source ${LFS_CI_ROOT}/lib/special_build.sh
[[ -z ${LFS_CI_SOURCE_uc_lfs_package}  ]] && source ${LFS_CI_ROOT}/lib/uc_lfs_package.sh

## @fn      usecase_LFS_KNIFE_BUILD()
#  @brief   run the usecase LFS Knife Build
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_BUILD() {
    requiredParameters KNIFE_LFS_BASELINE REQUESTOR_USERID

    # get the information from WFT (opt)
    # get the information from jenkins

    local currentDateTime=$(date +%Y%m%d-%H%M%S)
    local label=$(printf "KNIFE_%s.%s" ${KNIFE_LFS_BASELINE} ${currentDateTime})
    local baseLabel=${KNIFE_LFS_BASELINE/_PS_LFS_REL_/_PS_LFS_OS_}

    local svnReposUrl=$(getConfig LFS_PROD_svn_delivery_os_repos_url -t tagName:${baseLabel} )
    mustExistInSubversion ${svnReposUrl}/tags/${baseLabel}/doc/scripts/ revisions.txt
    local revision=$(svnCat ${svnReposUrl}/tags/${baseLabel}/doc/scripts/revisions.txt | cut -d" " -f3 | sort -nu | tail -n 1)

    local location=$(getConfig LFS_PROD_tag_to_branch -t tagName:${baseLabel})
    mustHaveValue "${location}" "location from base label"

    export LFS_CI_GLOBAL_BRANCH_NAME=${location}

    info "using revision ${location}@${revision} instead of ${KNIFE_LFS_BASELINE}"

    specialBuildPreparation KNIFE ${label} ${revision} ${location}

    return
}

## @fn      usecase_LFS_KNIFE_BUILD_PLATFORM()
#  @brief   build a lfs knife
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_BUILD_PLATFORM() {

    specialBuildCreateWorkspaceAndBuild

    info "build job finished."
    return
}


## @fn      usecase_LFS_KNIFE_PACKAGE()
#  @brief   run the usecase lfs knife package
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_PACKAGE() {
    requiredParameters LFS_CI_ROOT WORKSPACE

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustHaveLocationForSpecialBuild
    info "running usecase LFS package"
    ci_job_package

    specialBuildUploadAndNotifyUser KNIFE

    info "knife is done."
    return
}

