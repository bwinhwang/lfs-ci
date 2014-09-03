#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

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
        genericShareCleanup)         genericShareCleanup                   ;;
        *)
            error "subjob not known (${taskName})"
            exit 1;
        ;;
    esac

    return
}

## @fn      synchronizeShare()
#  @brief   syncrhonized items from one site to the remote site
#  @details the list of items to synchronize is based on the changelog
#           generated by the customSCM plugin.
#  @param   <none>
#  @return  <none>
synchronizeShare() {
    requiredParameters JOB_NAME BUILD_NUMBER LFS_CI_ROOT WORKSPACE

    export subTaskName=$(getSubTaskNameFromJobName)
    # syntax is <share>_to_<site>
    export shareType=$(cut -d_ -f 1 <<< ${subTaskName})
    export siteName=$(cut -d_ -f 3 <<< ${subTaskName})
    
    local localPath=$(getConfig    ADMIN_sync_share_local_directoryName)
    local remotePath=$(getConfig   ADMIN_sync_share_remote_directoryName)
    local remoteServer=$(getConfig ADMIN_sync_share_remote_hostname)
    local findDepth=$(getConfig    ADMIN_sync_share_check_depth)
    local find=$(getConfig         ADMIN_sync_share_find_command)
    local rsyncOpts=$(getConfig    ADMIN_sync_share_rsync_opts)
    mustHaveValue "${remoteServer}" "remote server"
    mustHaveValue "${remotePath}"   "remote path"
    mustHaveValue "${localPath}"    "local path"

    local rsyncOptions=$(getConfig RSYNC_options)

    unset shareType siteName

    copyChangelogToWorkspace ${JOB_NAME} ${BUILD_NUMBER}

    execute ssh ${remoteServer} chmod u+w $(dirname ${remotePath})
    execute ssh ${remoteServer} mkdir -p ${remotePath}

    # TODO: demx2fk3 2014-07-15 remove this later - temp solution
    # remove this
    if [[ -z ${findDepth} ]] ; then
        findDepth=1
    fi

    info "synchronize ${localPath} to ${remoteServer}:${remotePath}"
    local pathToSyncFile=$(createTempFile)
    ${LFS_CI_ROOT}/bin/xpath -q -e '/log/logentry/paths/path/node()' ${WORKSPACE}/changelog.xml  > ${pathToSyncFile}
    mustBeSuccessfull "$?" "xpath changelog.xml"

    if [[ -f ${pathToSyncFile} && ! -s ${pathToSyncFile} ]] ; then
        warning "nothing to sync"
        return
    fi         

    local buildDescription=$(perl -p -e 's:.*/::g' ${pathToSyncFile} | sort -u)
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${buildDescription:-no change}"

    ssh ${remoteServer} "${find} ${remotePath} -maxdepth $(( findDepth - 1 )) -exec chmod u+w {} \; " 
    mustBeSuccessfull $? "ssh chmod command"

    for entry in $(cat ${pathToSyncFile})
    do
        basePartOfEntry=${entry//${localPath}}
       [[ -d ${entry} ]] || continue
        info "transferting ${entry} to ${remoteServer}:${remotePath}/${basePartOfEntry}"
        execute ssh ${remoteServer} mkdir -p ${remotePath}/${basePartOfEntry}
        execute rsync -aHz -e ssh --stats ${rsyncOpts} ${entry}/ ${remoteServer}:${remotePath}/${basePartOfEntry}
    done

    info "synchronizing is done."

    return
}

genericShareCleanup() {
    requiredParameters JOB_NAME BUILD_NUMBER LFS_CI_ROOT WORKSPACE

    copyChangelogToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}
    mustExistFile ${WORKSPACE}/changelog.xml

    # ADMIN_-_genericShareCleanup_-_Ul
    export siteName=$(getSubTaskNameFromJobName)

    local remoteServer=$(getConfig ADMIN_sync_share_remote_hostname)
    mustHaveValue "${remoteServer}" "remote server name"
    mustHaveAccessableServer ${remoteServer}

    # we are handeling "old" pathes first:
    local tmpFile=$(createTempFile)
    ${LFS_CI_ROOT}/bin/xpath -q -e '/log/logentry/paths/path[@action="D"]/node()' ${WORKSPACE}/changelog.xml \
        > ${tmpFile}

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "triggered by ${UPSTREAM_PROJECT}/${UPSTREAM_BUILD}"

    local execute=execute
    local max=$(wc -l ${tmpFile} | cut -d" " -f1)
    local cnt=0
    for entry in $(cat ${tmpFile}) ; do
        cnt=$(( cnt + 1 ))
        info "[${cnt}/${max}] removing ${entry}"

        debug "fixing permissions on parent directory"
        $execute ssh ${remoteServer} "[[ -w $(dirname ${entry}) ]] || chmod u+w $(dirname ${entry})"

        debug "fixing permissions of removal candidate ${entry}"
        $execute ssh ${remoteServer} chmod -R u+w ${entry}

        debug "removing ${entry}"
        if [[ -e ${entry} ]] ; then
            local destination=$(echo ${entry} | sed "s:/:_:g")
            $execute mv -f ${entry} /build/home/${USER}/genericCleanup/${destination}
            $execute touch ${entry}
        fi

        local randomValue=${RANDOM}
        $execute ssh ${remoteServer} mv -f ${entry} ${entry}.deleted.${randomValue}
        $execute ssh ${remoteServer} rm -rf ${entry}.deleted.${randomValue}
    done

    # next: modified and added stuff
    # TODO: demx2fk3 2014-08-07 disabled, we dont want to put stuff to the remote site
#     ${LFS_CI_ROOT}/bin/xpath -q -e '/log/logentry/paths/path[@action="A"]/node()' ${WORKSPACE}/changelog.xml \
#         > ${tmpFile}
#     ${LFS_CI_ROOT}/bin/xpath -q -e '/log/logentry/paths/path[@action="M"]/node()' ${WORKSPACE}/changelog.xml \
#         >> ${tmpFile}
# 
#     for entry in $(cat ${tmpFile}) ; do
#         info "transferting ${entry} to ${remoteServer}"
# 
#         debug "fixing permissions on parent directory"
#         $execute ssh ${remoteServer} chmod u+w $(dirname ${entry})
# 
#         debug "creating new directory"
#         $execute ssh ${remoteServer} mkdir -p ${remotePath}/${entry}
# 
#         debug "rsyncing ${entry}"
#         info execute rsync -aHz -e ssh --stats ${entry}/ ${remoteServer}:${entry}/
#     done

    info "cleanup is done."
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

    execute rm -rf ${backupPath}/backup.11

    for i in $(seq 0 10 | tac) ; do
        [[ -d ${backupPath}/backup.${i} ]] || continue
        old=$(( i + 1 ))
        execute mv -f ${backupPath}/backup.${i} ${backupPath}/backup.${old}
    done

    if [[ -d ${backupPath}/backup.1 ]] ; then
        execute cp -rl ${backupPath}/backup.1 ${backupPath}/backup.0
    else
        execute mkdir -p ${backupPath}/backup.0/
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
