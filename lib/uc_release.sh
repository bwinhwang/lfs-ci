#!/bin/bash
## @file  uc_release.sh
#  @brief usecase release 

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion}      ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_jenkins}         ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_workflowtool}    ]] && source ${LFS_CI_ROOT}/lib/workflowtool.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh
[[ -z ${LFS_CI_SOURCE_try}             ]] && source ${LFS_CI_ROOT}/lib/try.sh
[[ -z ${LFS_CI_SOURCE_fingerprint}     ]] && source ${LFS_CI_ROOT}/lib/fingerprint.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @param   <none>
#  @return  <none>
ci_job_release() {
    local subJob=$(getSubTaskNameFromJobName)
    mustHaveValue "${subJob}" "subtask name"

    info "task is ${subJob}"
    case ${subJob} in
        create_proxy_release_tag)             warning "disabled due to BI#293"                        ;;
        update_dependency_files)              usecase_LFS_RELEASE_UPDATE_DEPS                         ;;
        upload_to_subversion)                 usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION                ;;
        build_results_to_share)               usecase_LFS_RELEASE_SHARE_BUILD_ARTIFACTS               ;;
        build_results_to_share_kernelsources) usecase_LFS_RELEASE_SHARE_BUILD_ARTIFACTS_KERNELSOURCES ;;
        create_release_tag)                   usecase_LFS_RELEASE_CREATE_RELEASE_TAG                  ;;
        create_source_tag)                    usecase_LFS_RELEASE_CREATE_SOURCE_TAG                   ;;
        pre_release_checks)                   usecase_LFS_RELEASE_PRE_RELEASE_CHECKS                  ;;
        summary)                              usecase_LFS_RELEASE_SEND_RELEASE_NOTE                   ;;
        *) fatal "subJob not known (${subJob})" ;;
    esac

    return
}

## @fn      usecase_LFS_RELEASE_PREPARE()
#  @brief   usecase LFS Release Prepare
#  @details this usecase is just doing some preparations, so that the following
#           subjobs can run without any problem
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_PREPARE() {
    mustBePreparedForReleaseTask
    createArtifactArchive
    return
}
