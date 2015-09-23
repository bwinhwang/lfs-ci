#!/bin/bash
# @file  uc_release.sh
# @brief usecase release 

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_release}         ]] && source ${LFS_CI_ROOT}/lib/release.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @detail  This is a dispatcher for the jobs in old style.
#           This can be removed, when all jobs are migrated.
#  @param   <none>
#  @return  <none>
ci_job_release() {
    local subJob=$(getSubTaskNameFromJobName)
    mustHaveValue "${subJob}" "subtask name"

    info "task is ${subJob}"
    local usecase=
    case ${subJob} in
        build_results_to_share)               LFS_CI_GLOBAL_USECASE=LFS_RELEASE_SHARE_BUILD_ARTIFACTS               ;;
        build_results_to_share_kernelsources) LFS_CI_GLOBAL_USECASE=LFS_RELEASE_SHARE_BUILD_ARTIFACTS_KERNELSOURCES ;;
        create_release_tag)                   LFS_CI_GLOBAL_USECASE=LFS_RELEASE_CREATE_RELEASE_TAG                  ;;
        create_source_tag)                    LFS_CI_GLOBAL_USECASE=LFS_RELEASE_CREATE_SOURCE_TAG                   ;;
        pre_release_checks)                   LFS_CI_GLOBAL_USECASE=LFS_RELEASE_PRE_RELEASE_CHECKS                  ;;
        summary)                              LFS_CI_GLOBAL_USECASE=LFS_RELEASE_SEND_RELEASE_NOTE                   ;;
        update_dependency_files)              LFS_CI_GLOBAL_USECASE=LFS_RELEASE_UPDATE_DEPS                         ;;
        upload_to_subversion)                 LFS_CI_GLOBAL_USECASE=LFS_RELEASE_UPLOAD_TO_SUBVERSION                ;;
        create_proxy_release_tag)             warning "disabled due to BI#293"                                      ;;
        *)                                    fatal "subJob not known (${subJob})"                                  ;;
    esac

    requiredParameters LFS_CI_ROOT

    export LFS_CI_GLOBAL_USECASE
    sourceFile=$(getConfig LFS_CI_usecase_file)
    mustExistFile ${LFS_CI_ROOT}/lib/${sourceFile}
    source ${LFS_CI_ROOT}/lib/${sourceFile}
    usecase_${LFS_CI_GLOBAL_USECASE}

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
    databaseEventReleaseStarted
    createArtifactArchive
    return
}

