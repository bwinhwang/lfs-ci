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

}

cleanUpArtifactsShare() {

    local listOfJobsWithArtifacts=$(ls ${artifactesShare})

    for job in ${listOfJobsWithArtifacts} ; do
        info "cleanup artifacts from ${job}"
        for build in ${artifactesShare}/${job} ; do
            [[ -e ${jenkinsMasterServerPath}/${job}/builds/${build} ]] && continue
            info "cleanup ${job} / ${build}"
        done

    done

}
