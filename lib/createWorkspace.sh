#!/bin/bash
## @file  createWorkspace.sh 
#  @brief creating or updating a workspace

LFS_CI_SOURCE_createWorkspace='$Id$'

[[ -z ${LFS_CI_SOURCE_artifacts}   ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_fingerprint} ]] && source ${LFS_CI_ROOT}/lib/fingerprint.sh

## @fn      createOrUpdateWorkspace()
#  @brief   create a new or update an existing workspace
#  @param   {option}    -u | --allowUpdate 
#  @return  <none>
createOrUpdateWorkspace() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local shouldUpdateWorkspace=

    #  TODO: demx2fk3 2014-11-24 add getopt here
    while [[ $# -gt 0 ]]
    do
        case $1 in
            -u|--allowUpdate) shouldUpdateWorkspace=1  ;;
            (-*)              fatal "unrecognized option $1" ;;
        esac
        shift;
    done

    debug "create new or update existing workspace ${workspace}"

    if [[ -d ${workspace}/.build_workdir && ! -z ${shouldUpdateWorkspace} ]] ; then
        debug "workspace exists, try to update..."
        updateWorkspace
    else
        debug "workspace does not exist, create a new one..."
        createWorkspace            
    fi

    return
}

## @fn      updateWorkspace()
#  @brief   update a workspace with build updateall
#  @details if there is still a valid workspace from previous run, we
#           want to reuse this workspace and use build updatell in
#  @param   <none>
#  @return  <none>
updateWorkspace() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    debug "changing directory to ${workspace}"
    cd ${workspace}

    # we want the latest revision state file, so we clean it up first
    execute rm -rf ${WORKSPACE}/revisions.txt

    # we need the revision to update to the requested (from upstream / revision state file) revision
    local revision=$(latestRevisionFromRevisionStateFile)
    mustHaveValue "${revision}" "revision from revision state file"

    local build="build updateall -r ${revision}"

    info "running build updateall with revision ${revision:-latest}"
    if ! execute --ignore-error ${build} ; then
        # FALLBACK: updating the workspace failed, we will recreate the workspace
        warning "updating the workspace failed, removing and recreating workspace now..."
        createWorkspace
        return
    fi

    info "workspace update was successful"
    # TODO: demx2fk3 2014-11-24 checking for new src-directories
    # we should also check, if all the required src-directories are in place.
    # BUT we have a little problem in the concept here. We want to check
    # again the entries in the build file, but there is something missing
    # in the name of the build target: e.g.:
    # project name: LFS_CI_-_trunk_-_Build_-_FSM-r3_-_fsm3_octeon2
    # Name in Buildfile: src-list_LFS_FSM-r4
    # So the information about the taskName is missing in Buildfile.
    # the name in Buildfile should be something like: src-lis_LFS_Build_FSM-r4.
    # If we want to change this, we have to do this in a lot of branches....

    mustHaveValidWorkspace

    # TODO: demx2fk3 2014-11-24 check, if this is working in update usecase
    mustHaveLocalSdks

    cleanupBldDirectoryInWorkspace
    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}

    return
}

## @fn      cleanupBldDirectoryInWorkspace()
#  @brief   cleanup the bld directory of a workspace
#  @details remove everything, which is a directory or a file
#  @param   <none>
#  @return  <none>
cleanupBldDirectoryInWorkspace() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    [[ -d ${workspace}/bld ]] || return

    for directory in ${workspace}/bld/* ; do
        [[ ! -e ${directory} ]] && continue
        [[   -L ${directory} ]] && continue
        trace "removing ${directory}" 
        execute rm -rf ${directory}
    done
        
    return
}

## @fn      createWorkspace()
#  @brief   create a new workspace for LFS
#  @details this method is very huge. It creates a new workspace for a projects.
#           this includes several steps:
#           * create a new directory                             (build setup)
#           * cleanup the old workspace if exists
#           * switch to the correct location (aka branch)        (build newlocations)
#           * get the list of required subsystem
#           * check out the subsystem from svn                   (build adddir)
#  @param   <none>
#  @return  <none>
createWorkspace() {
    info "creating the workspace..."

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    local location=$(getLocationName)
    mustHaveLocationName
    info "location is ${location} / ${LFS_CI_GLOBAL_LOCATION_NAME:-none global location}"

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"

    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}" "subtask name"

    local srcDirectory=$(getConfig LFS_CI_UC_build_subsystem_to_build)
    mustHaveValue "${srcDirectory}" "src directory"
    info "requested source directory: ${srcDirectory}"

    local revision=$(latestRevisionFromRevisionStateFile)
    mustHaveValue "${revision}" "revision from revision state file"
    info "using revision ${revision} from revision state file"

    debug "parameter: revision ${revision}"
    debug "parameter: location ${location}"

    setupNewWorkspace
    mustHaveWritableWorkspace

    debug "changing directory to ${workspace}"
    cd ${workspace}

    switchToNewLocation ${location}
    switchSvnServerInLocations ${location}
    checkoutSubprojectDirectories ${srcDirectory} ${revision}

    buildTargets=$(requiredSubprojectsForBuild)
    mustHaveValue "${buildTargets}" "build targets"
    info "using src-dirs: ${buildTargets}"

    local amountOfTargets=$(echo ${buildTargets} | wc -w)
    local counter=0

    for src in ${buildTargets} ; do
        local revision=$(latestRevisionFromRevisionStateFile)
        mustHaveValue "${revision}" "revision from revision state file"

        counter=$(expr ${counter} + 1)
        info "(${counter}/${amountOfTargets}) checking out sources for ${src} rev ${revision:-latest}"
        checkoutSubprojectDirectories "${src}" "${revision}"
    done 

    mustHaveValidWorkspace

    mustHaveLocalSdks
    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}

    return
}


## @fn      latestRevisionFromRevisionStateFile()
#  @brief   get the latest revision number from the revision state file
#  @details the revision state file is written by custom scm plugin and
#           contains all the used svn urls and revisions
#  @return  latest revision number
latestRevisionFromRevisionStateFile() {
    requiredParameters WORKSPACE

    local revision=

    if [[ ! -f ${WORKSPACE}/revisions.txt ]] ; then
        requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD 

        local taskName=$(getTaskNameFromJobName)
        local jobName=
        local buildNumber=

        # In case of the build job, the fingerprint file is not available yet.
        # For this case, we take the upstream informations.
        if [[ ${taskName} =~ Build ]] ; then
            debug "using upstream ${UPSTREAM_BUILD} / ${UPSTREAM_PROJECT}"
        else
            jobName=$(getBuildJobNameFromFingerprint)  
            buildNumber=$(getBuildBuildNumberFromFingerprint)
        fi  
        
        if [[ -z ${jobName} ]] ; then
            jobName=${UPSTREAM_PROJECT}
        fi  
        if [[ -z ${buildNumber} ]] ; then
            buildNumber=${UPSTREAM_BUILD}
        fi  
        
        # last check...
        if [[ -z ${jobName} ]] ; then
            fatal "this should not happen: jobName empty after fingerprint or from upstream"
        fi  
        if [[ -z ${buildNumber} ]] ; then
            fatal "this should not happen: buildNumber empty after fingerprint or from upstream"
        fi  

        info "using revision state file from ${jobName} / ${buildNumber} based on ${UPSTREAM_PROJECT} / ${UPSTREAM_BUILD}"
        copyRevisionStateFileToWorkspace ${jobName} ${buildNumber} 
    fi

    if [[ -r "${WORKSPACE}/revisions.txt" ]] ; then
        # TODO: demx2fk3 2014-06-25 stupid bug: adddir will not update to a higher revision, 
        #                           if the src-directory already exists...
        # revision=$(grep "^${src} " ${WORKSPACE}/revisions.txt | cut -d" " -f3)
        revision=$(grep -v "^#"  ${WORKSPACE}/revisions.txt | cut -d" " -f 3 | sort -n -u | tail -n 1)
    fi

    echo ${revision}
}

## @fn      requiredSubprojectsForBuild()
#  @brief   get the required subprojects for a build
#  @details this runs build -C src-project src-list_<product>_<subtask>
#  @todo    the task type is missing here. we have to fix this sometimes..
#  @param   <none>
#  @return  list of src projects, which are required for the build
requiredSubprojectsForBuild() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"

    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}" "sub task name"

    local onlySourceDirectory=$(getConfig LFS_CI_UC_build_onlySourceDirectories)
    local build="build -W \"${workspace}\""

    local srcDirectory=$(getConfig LFS_CI_UC_build_subsystem_to_build)
    mustHaveValue "${srcDirectory}" "src directory"
    info "requested source directory: ${srcDirectory}"

    if [[ ${onlySourceDirectory} ]] ; then
        buildTargets=${onlySourceDirectory}
    else
        info "getting required src-directories for ${srcDirectory}"
        local buildTargets=$(execute -n ${build} -C ${srcDirectory} src-list_${productName}_${subTaskName}) 
        mustHaveValue "${buildTargets}" "no build targets configured"
        buildTargets="$(getConfig LFS_CI_UC_build_additionalSourceDirectories) ${buildTargets}"
    fi

    echo ${buildTargets}
}

## @fn      mustHaveLocalSdks()
#  @brief   ensure, that the "links to share" in bld are pointing to
#           a local directory
#  @detail  if there is a link in bld directory to the build share,
#           the method will trigger the copy of this directory to the local
#           directory
#  @param   <none>
#  @return  <none>
mustHaveLocalSdks() {
    requiredParameters LFS_CI_SHARE_MIRROR

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    debug "checking for links in bld"

    # copy the sdk, pkgpool to local disk takes a lot of time
    # in some cases (knife), we want to avoid this time and
    # will use the sdk, pkgpool, ... from share
    local canCopySdksToLocalDisk=$(getConfig LFS_CI_uc_build_can_copy_sdks_to_local_harddisk)
    [[ ${canCopySdksToLocalDisk} ]] || return

    for bld in ${workspace}/bld/*
    do
        [[ -e ${bld} ]] || continue
        [[ -L ${bld} ]] || continue

        local pathToSdk=$(readlink ${bld})
        mustExistDirectory ${pathToSdk}

        local tag=$(basename ${pathToSdk})
        mustHaveValue "${tag}" "tag of used bld results"

        local subsystem=$(basename ${bld})
        mustHaveValue "${subsystem}" "name of subsystem"

        local localCacheDir=${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/${subsystem}
        
        local canCopySdksToLocalDisk=$(getConfig LFS_CI_uc_build_can_copy_sdks_to_local_harddisk -t subsystem:${subsystem})
        [[ ${canCopySdksToLocalDisk} ]] || return

        info "checking for ${subsystem} / ${tag} on local disk"

        if [[ ! -d ${localCacheDir}/${tag} ]] ; then
            synchroniceToLocalPath ${bld}
        else
            execute touch ${localCacheDir}/data/${tag}
        fi

        execute rm -rf ${bld}
        execute ln -sf ${localCacheDir}/${tag} ${bld}
    done

    return
}

## @fn      synchroniceToLocalPath()
#  @brief   syncronice the given local path from there to the local cache directory
#  @details in bld, there are links to the build share. We want to avoid using build
#           share, because it's to slow. So we are rsyncing the directories from the
#           share to a local directory.
#           There are some safties active to avoid problems during syncing.
#  @param   {localPath}    local bld path
#  @return  <none>
synchroniceToLocalPath() {
    local localPath=$1
    local remotePath=$(readlink ${localPath})
    local subsystem=$(basename ${localPath})
    local tag=$(basename ${remotePath})
    local serverName=$(getConfig LINSEE_server)

    requiredParameters LFS_CI_SHARE_MIRROR

    local localCacheDir=${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/${subsystem}
    if [[ ${subsystem} == "pkgpool" ]] ; then
        local rsync_opts=-L
    fi        

    if [[ ! -d ${localCacheDir}/data ]] ; then
        execute mkdir -p ${localCacheDir}/data
    fi

    if [[ ! -e ${localCacheDir}/${tag} ]] ; then
        progressFile=${localCacheDir}/data/${tag}.in_progress

        # mkdir is an atomic operation. if it exists, mkdir fails
        if mkdir ${progressFile} 2> /dev/null ; then

            info "synchronize ${subsystem}/${tag} to local filesystem"
            execute mkdir -p ${localCacheDir}/data

            execute -r 10 \
                rsync --archive --numeric-ids --delete-excluded --ignore-errors     \
                --hard-links --sparse --exclude=.svn --rsh=ssh                      \
                ${rsync_opts}                                                       \
                ${serverName}:${remotePath}/                                        \
                ${localCacheDir}/data/${tag}/

            execute ln -sf data/${tag} ${localCacheDir}/${tag}
            execute rm -rf ${progressFile}
        else
            info "waiting for ${tag} on local filesystem"
            # 2014-03-12 demx2fk3 TODO make this configurable
            sleep 60
            synchroniceToLocalPath ${localPath}
        fi
    fi

    return
}

## @fn      mustHavePreparedWorkspace()
#  @brief   prepare the workspace with required artifacts and other stuff
#  @param   {upstreamProject}    name of the upstream project
#  @param   {upstreamBuild}      build number of the upstream project
#  @todo    TODO: demx2fk3 2015-06-08 move into a different file (maybe common.sh)
#  @return  <none>
mustHavePreparedWorkspace() {

    requiredParameters JOB_NAME BUILD_NUMBER
    
    local opt_noCleanWorkspace=
    local opt_noBuildDescription=

    local opts=$(getopt -o BC -l no-build-description,no-clean-workspace -- "$@")
    if [[ $? != 0 ]] ; then
         fatal "getopt parsing error in mustHavePreparedWorkspace"
    fi

    eval set -- "${opts}"

    while true ; do
        case "$1" in
            -B | --no-build-description) opt_noBuildDescription=1 ; shift ;;
            -C | --no-clean-workspace) opt_noCleanWorkspace=1 ; shift ;;
            --) shift; break;;
        esac
    done

    local upstreamProject=${1}
    local upstreamBuild=${2}

    if [[ -z ${upstreamProject} ]] ; then
        requiredParameters UPSTREAM_PROJECT
        upstreamProject=${UPSTREAM_PROJECT}
    fi
    if [[ -z ${upstreamBuild} ]] ; then
        requiredParameters UPSTREAM_BUILD
        upstreamBuild=${UPSTREAM_BUILD}
    fi

    mustHaveValue "${upstreamProject}" "upstream project"
    mustHaveValue "${upstreamBuild}"   "upstream build"

    local workspace=$(getWorkspaceName)
    [[ -z ${opt_noCleanWorkspace} ]] && mustHaveCleanWorkspace

    if [[ -z ${opt_noBuildDescription} ]] ; then
        local requiredArtifacts=$(getConfig LFS_CI_prepare_workspace_required_artifacts)
        copyAndExtractBuildArtifactsFromProject "${upstreamProject}" "${upstreamBuild}" "${requiredArtifacts}"

        mustHaveNextLabelName
        local labelName=$(getNextReleaseLabel)

        setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${labelName}
    fi

    return
}

