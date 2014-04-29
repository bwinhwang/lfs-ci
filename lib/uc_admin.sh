#!/bin/bash

## @fn      ci_job_admin()
#  @brief   dispatcher for admin jobs, detailed jobs is in seperated functions
#  @param   <none>
#  @return  <none>
ci_job_admin() {
    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    case ${subJob} in
        backupJenkins)
            backupJenkinsMasterServerInstallation
        ;;
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

## @fn      cleanUpArtifactsShare()
#  @brief   clean up the artifcats from share, if a build of a job was removed / delete from the jenkins master
#  @details the jenkins server removes the builds from ${JENKINS_HOME}/jobs/<job>/builds/ directory after some
#           time (or number of builds). We have also to clean up the artifacts on the build share, because we
#           are handling the artifacts by ourself
#  @param   <none>
#  @return  <none>
cleanUpArtifactsShare() {
    local listOfJobsWithArtifacts=$(ls ${artifactesShare})
    # TODO: demx2fk3 2014-04-16 add error handling, if listOfJobsWithArtifacts is empty

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

backupJenkinsMasterServerInstallation() {

    local backupPath=${jenkinsMasterServerBackupPath}

    execute mkdir -p ${backupPath}

    rm -rf ${backupPath}/backup.11
    for i in $(seq -w 1 10 | tac) ; do
        old=$(( i + 1 ))
        info mv ${backupPath}/backup.${old} ${backupPath}/backup.${i}
    done
    
}
