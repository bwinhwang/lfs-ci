#!/bin/bash

## @fn      ci_job_admin()
#  @brief   dispatcher for admin jobs, detailed jobs is in seperated functions
#  @param   <none>
#  @return  <none>
ci_job_admin() {
    local taskName=$(getTaskNameFromJobName)
    # mustHaveTargetBoardName

    case ${taskName} in
        backupJenkins)               backupJenkinsMasterServerInstallation ;;
        cleanUpArtifactsShare)       cleanupArtifactsShare                 ;;
        cleanupBaselineShares)       cleanupBaselineShares                 ;;
        cleanupOrphanJobDirectories) cleanupOrphanJobDirectories           ;;
        cleanupOrphanWorkspaces)     cleanupOrphanWorkspaces               ;;
        synchronizeShare)            synchronizeShare                      ;;
        *)
            error "subjob not known (${taskName})"
            exit 1;
        ;;
    esac

    return
}

synchronizeShare() {
    requiredParameters JOB_NAME BUILD_NUMBER LFS_CI_ROOT WORKSPACE

    export subTaskName=$(getSubTaskNameFromJobName)
    local localPath=$(getConfig ADMIN_sync_share_local_directoryName)
    local remotePath=$(getConfig ADMIN_sync_share_remote_directoryName)
    local remoteServer=$(getConfig ADMIN_sync_share_remote_hostname)

    copyChangelogToWorkspace ${JOB_NAME} ${BUILD_NUMBER}

    execute ssh ${remoteServer} mkdir -p ${remotePath}

    info "synchronize ${localPath} to ${remoteServer}:${remotePath}"
    for entry in $(${LFS_CI_ROOT}/bin/xpath -q -e '/log/logentry/paths/path/node()' ${WORKSPACE}/changelog.xml )
    do
        info "transferting ${entry} to ${remoteServer}:${remotePath}"
        execute rsync -ave ssh --stats ${entry} ${remoteServer}:${remotePath}
    done

    return
}

## @fn      cleanupArtifactsShare()
#  @brief   clean up the artifcats from share, if a build of a job was removed / delete from the jenkins master
#  @details the jenkins server removes the builds from ${JENKINS_HOME}/jobs/<job>/builds/ directory after some
#           time (or number of builds). We have also to clean up the artifacts on the build share, because we
#           are handling the artifacts by ourself
#  @param   <none>
#  @return  <none>
cleanupArtifactsShare() {
    local artifactesShare=$(getConfig artifactesShare)

    local listOfJobsWithArtifacts=$(ls ${artifactesShare})
    mustHaveValue "${listOfJobsWithArtifacts}"

    local serverPath=$(getConfig jenkinsMasterServerPath)

    local counter=0

    for job in ${listOfJobsWithArtifacts} ; do
        info "cleanup artifacts of ${job}"
        for build in ${artifactesShare}/${job}/* ; do
            [[ -e ${build} ]] || continue
            build=$(basename ${build})
            if [[ ! -e ${serverPath}/jobs/${job}/builds/${build} ]] ; then
                info "removing artifacts of ${job} / ${build}"
                execute rm -rf ${artifactesShare}/${job}/${build}/
                counter=$(( counter + 1 ))
            else
                trace "keep ${job} / ${build}"
            fi
        done

    done

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "removed ${counter} artifacts"

    info "cleanup done"

    return
}

## @fn      backupJenkinsMasterServerInstallation()
#  @brief   backup the jenkins installation from the master server on the build share
#  @details we keep 10 backups of the jenkins installation, we use the 
#  @todo    �description of incomplete business�
#  @param   <none>
#  @return  <none>
backupJenkinsMasterServerInstallation() {

    local backupPath=$(getConfig jenkinsMasterServerBackupPath)
    local serverPath=$(getConfig jenkinsMasterServerPath)

    mustHaveValue ${backupPath}
    mustHaveValue ${serverPath}

    execute mkdir -p ${backupPath}
    execute rm -rf ${backupPath}/backup.11

    for i in $(seq 0 100 | tac) ; do
        [[ -d ${backupPath}/backup.${i} ]] || continue
        old=$(( i + 1 ))
        execute mv -f ${backupPath}/backup.${i} ${backupPath}/backup.${old}
    done

    if [[ -d ${backupPath}/backup.1 ]] ; then
        execute cp -rl ${backupPath}/backup.1 ${backupPath}/backup.0
    fi

    execute rsync -av --delete --exclude=workspace ${serverPath}/. ${backupPath}/backup.0/.
    execute touch ${backupPath}/backup.0

    info "backup done"

    return
}

## @fn      cleanupOrphanWorkspaces()
#  @brief   cleanup the orphan workspaces on the node, where the job does not exists any more on the master server
#  @param   <none>
#  @return  <none>
cleanupOrphanWorkspaces() {
   
    # better solution?
    # * create a job for each node
    # * limit the job on just this node
    # get the workspace directories aka job name of this node
    # checks, if the job exists on the master
    # if not, remove the directory for the node
    debug "not implemented yet"

    return
}

## @fn      cleanupBaselineShares()
#  @brief   cleanup the baselines on the local share on the build node, which are not required any more
#  @details �full description�
#  @param   <none>
#  @return  <none>
cleanupBaselineShares() {

    # forall bld-"types" in the local share directory
    # checks the data diretories
    # ensure, that no other job is running on the node, otherwise exist with a nice description
    # nice algorithm to find out, which directory can be removed
    # remove the directory
    debug "not implemented yet"

    if [[ ${LFS_CI_SHARE_MIRROR} ]] ; then
        mustExistDirectory "${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/"
        info "changing write permissions..."
        execute chmod -R u+w ${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/
        info "removing local baseline share"
        execute rm -rf ${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/
    fi

    return
}


## @fn      cleanupOrphanJobDirectories()
#  @brief   clean up the orphan job directories (mostly on slaves)
#  @details if a job directory is not modified after x days, the directory will be removed.
#           if the job directory is still required, the jenkins slave will recreate the directory
#  @param   <none>
#  @return  <none>
cleanupOrphanJobDirectories() {
    debug "not implemented yet"
    return
}
