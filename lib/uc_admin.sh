#!/bin/bash

ci_job_admin() {
    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    case ${subJob} in
        cleanUpArtifactsShare)
            cleanUpArtifactsShare
        ;;
        *)
            error "subjob not known (${subjob})"
            exit 1;
        ;;
    esac

    return
}

cleanUpArtifactsShare() {
    local listOfJobsWithArtifacts=$(ls ${artifactesShare})

    for job in ${listOfJobsWithArtifacts} ; do
        info "cleanup artifacts of ${job}"
        for build in ${artifactesShare}/${job}/* ; do
            [[ -e ${build} ]] || continue
            build=$(basename ${build})
            if [[ ! -e ${jenkinsMasterServerPath}/jobs/${job}/builds/${build} ]] ; then
                info "removing artifacts of ${job} / ${build}"
                execute rm -rf ${artifactesShare}/${job}/${build}/
            else
                trace "keep ${job} / ${build}"
            fi
        done

    done

    return
}
