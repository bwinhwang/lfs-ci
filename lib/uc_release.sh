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
        update_dependency_files)
            updateDependencyFiles "${buildJobName}" "${buildBuildNumber}"
        ;;
        upload_to_subversion)
            local branch=$(getConfig LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch)
            mustHaveValue "${branch}" "branch name"
            # from subversion.sh
            uploadToSubversion "${releaseDirectory}/os" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"
        ;;
        build_results_to_share)
            extractArtifactsOnReleaseShare "${buildJobName}" "${buildBuildNumber}"
        ;;
        build_results_to_share_kernelsources)
            extractArtifactsOnReleaseShareKernelSources "${buildJobName}" "${buildBuildNumber}"
        ;;
        create_release_tag)
            createReleaseTag ${buildJobName} ${buildBuildNumber}
        ;;
        create_proxy_release_tag) 
            # createProxyReleaseTag ${buildJobName} ${buildBuildNumber}
            warning "disabled due to BI#293"
        ;;
        create_source_tag) 
            createTagOnSourceRepository ${buildJobName} ${buildBuildNumber}
        ;;
        pre_release_checks)
            databaseEventReleaseStarted
            prereleaseChecks
        ;;
        summary)
            sendReleaseNote "${TESTED_BUILD_JOBNAME}" "${TESTED_BUILD_NUMBER}" \
                            "${buildJobName}"         "${buildBuildNumber}"
            databaseEventReleaseFinished
            createArtifactArchive
        ;;
        *)
            error "subJob not known (${subJob})"
            exit 1
        ;;
    esac

    return
}

