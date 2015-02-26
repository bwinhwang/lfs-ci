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

    specialBuildPreparation KNIFE ${label} ${KNIFE_LFS_BASELINE} "none" 

    return
}

## @fn      usecase_LFS_KNIFE_BUILD_PLATFORM()
#  @brief   build a lfs knife
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_BUILD_PLATFORM() {
    requiredParameters KNIFE_LFS_BASELINE WORKSPACE UPSTREAM_PROJECT UPSTREAM_BUILD

    local baseLabel=${KNIFE_LFS_BASELINE}
    mustHaveValue "${baseLabel}" "base label"

    # create a workspace
    # TODO: demx2fk3 2015-02-26 do this in a different way or move it to a different place
    debug "create own revision control file"
    export tagName=${baseLabel}
    local svnReposUrl=$(getConfig LFS_PROD_svn_delivery_os_repos_url)
    mustExistInSubversion ${svnReposUrl}/tags/${baseLabel}/doc/scripts/ revisions.txt
    local revision=$(svnCat ${svnReposUrl}/tags/${baseLabel}/doc/scripts/revisions.txt | cut -d" " -f3 | sort -nu | tail -n 1)
    echo "src-knife ${svnReposUrl}/tags/${baseLabel} ${revision}" > ${WORKSPACE}/revisions.txt

    # faking the branch name for workspace creation...
    location=$(getConfig LFS_PROD_tag_to_branch)

    if [[ -z ${location} ]] ; then
        fatal "this branch is not prepared to build knives"
    fi

    # for FSM-r4, it's have to do this in a different way..
    if [[ ${subTaskName} = "FSM-r4" ]] ; then
        case ${location} in
            trunk) location=FSM_R4_DEV ;;
            *)     # TODO: demx2fk3 2015-02-03 add check, if new location exists, otherwise no build
                   location=${location}_FSMR4 ;;
        esac
    fi
    mustHaveValue "${location}" "location"
    export LFS_CI_GLOBAL_BRANCH_NAME=${location}

    if ! specialBuildisRequiredForLrc ${location} ; then
        warning "build is not required."
        exit 0
    fi

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

    info "running usecase LFS package"
    ci_job_package

    specialBuildUploadAndNotifyUser

    info "knife is done."
    return
}
