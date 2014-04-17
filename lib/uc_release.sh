#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @param   <none>
#  @return  <none>
ci_job_release() {

    requiredParameters TESTED_BUILD_JOBNAME TESTED_BUILD_NUMBER

    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName
    local branch=$(getBranchName)
    # TODO: demx2fk3 2014-04-16 add mustHaveBranchName here

    local upstreamsFile=$(createTempFile)

    ${LFS_CI_ROOT}/bin/getUpStreamProject -j ${TESTED_BUILD_JOBNAME}      \
                                          -b ${TESTED_BUILD_NUMBER}       \
                                          -h ${jenkinsMasterServerPath} > ${upstreamsFile}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    if ! grep -q Package ${upstreamsFile} ; then
        error "cannot find upstream Package job / build"
        exit 1
    fi

    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local packageJobName=$(grep Package ${upstreamsFile} | cut -d: -f1)
    local buildBuildNumber=$(grep Build ${upstreamsFile} | cut -d: -f2)
    local buildJobName=$(grep Build ${upstreamsFile} | cut -d: -f1)

    # TODO: demx2fk3 2014-04-16 add check for valid values here

    info "found package job: ${packageJobName} / ${packageBuildNumber}"
    
    local workspace=${lfsCiBuildsShare}/${branch}/build_${packageBuildNumber}
    if [[ ! -d ${workspace} ]] ; then
        error "can not find workspace of package job on build share (${workspace})"
        exit 1
    fi

    debug "found results of package job on share: ${workspace}"

    local subJob=$(getTargetBoardName)

    info "subJob is ${subJob}"
    case ${subJob} in
        upload_to_subversion)
            # from subversion.sh
            uploadToSubversion "${workspace}" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"
        ;;
        build_results_to_share)
            extractArtifactsOnReleaseShare "${buildJobName}" "${buildBuildNumber}"
        ;;
        *)
            error "subjob not known (${subjob})"
            # TODO: demx2fk3 2014-04-16 add exit 1 here
        ;;
    esac

    return
}

extractArtifactsOnReleaseShare() {
    local jobName=$1
    local buildNumber=$2
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local labelName=$(getNextLabelName)
    # TODO: demx2fk3 2014-04-17 add mustHaveLabelName

    copyAndextractBuildArtifactsFromProject "${jobName}" "${buildNumber}"

    cd ${workspace}/bld/
    for dir in bld-*-* ; do
        [[ -d ${dir} ]] || continue
        basename=$(basename ${dir})

        info "copy ${basename} to buildresults share"
        execute mv ${basename} ${labelName}
        execute mkdir ${basename}
        execute mv ${labelName} ${basename}

        execute rsync -avrP ${workspace}/bld/. ${jenkinsMasterServerHostName}:${lfsCiBuildsShare}/buildresults/
    done

    info "clean up workspace"
    execute rm -rf ${workspace}/bld

    return
}

copyToReleaseShareOnSite() {
    local workspace=$1
    local destination=$2

    info "impelemente this"

    return
}

