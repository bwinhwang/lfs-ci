#!/bin/bash

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @param   <none>
#  @return  <none>
ci_job_release() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName
    local branch=$(getBranchName)
    # TODO: demx2fk3 2014-04-16 add mustHaveBranchName here

    local upstreamsFile=$(createTempFile)

    ${LFS_CI_ROOT}/bin/getUpStreamProject -j ${UPSTREAM_PROJECT}      \
                                          -b ${UPSTREAM_BUILD}        \
                                          -h ${jenkinsMasterServerPath} > ${upstreamsFile}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    if ! grep -q Package ${upstreamsFile} ; then
        error "cannot find upstream Package job / build"
        exit 1
    fi

    local upstreamBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local upstreamJobName=$(grep Package ${upstreamsFile} | cut -d: -f1)

    # TODO: demx2fk3 2014-04-16 add check for valid values here

    info "found upstream package job: ${upstreamJobName} / ${upstreamBuildNumber}"
    
    local workspace=${lfsCiBuildsShare}/${branch}/build_${upstreamBuildNumber}
    if [[ ! -d ${workspace} ]] ; then
        error "can not find workspace of upstream job on build share (${workspace})"
        exit 1
    fi

    debug "found results of package job on share: ${workspace}"

    info "subjob is ${subjob}"
    case ${subJob} in
        upload_to_subversion)
            # from subversion.sh
            uploadToSubversion "${workspace}" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"
        ;;
        *)
            error "subjob not known (${subjob})"
            # TODO: demx2fk3 2014-04-16 add exit 1 here
        ;;
    esac

    return
}

