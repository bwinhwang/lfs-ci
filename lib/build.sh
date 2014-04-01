#!/bin/bash

## @fn      ci_job_build()
#  @brief   usecase job ci build
#  @details the use case job ci build makes a clean build 
#  @param   <none>
#  @return  <none>
ci_job_build() {

    info "creating the workspace..."
    _createWorkspace

    info "building targets..."
    _build        

    info "upload results to artifakts share."
    _createArtifactArchive

    info "build job finished."
    return 0
}

## @fn      ci_job_package()
#  @brief   create a package from the build results for the testing / release process
#  @details copy all the artifacts from the sub jobs into the workspace and create the release structure
#  @todo    implement this
#  @param   <none>
#  @return  <none>
ci_job_package() {
    info "package the build results"

    # from Jenkins: there are some environment variables, which are pointing to the downstream jobs
    # which are execute within this jenkins jobs. So we collect the artifacts from those jobs
    # and untar them in the workspace directory.
    # 
    # TRIGGERED_BUILD_RUN_COUNT_LFS_CI_trunk_Build_LRC_lcpa=1
    # TRIGGERED_BUILD_NUMBER_LFS_CI_trunk_Build_FSM_r3_qemu_64=1
    # TRIGGERED_JOB_NAMES=LFS_CI_trunk_Build_FSM_r2_qemu,LFS_CI_trunk_Build_LRC_lcpa,LFS_CI_trunk_Build_FSM_r2_fcmd,LFS_CI_trunk_Build_UBOOT_fcta,LFS_CI_tr

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    trace "workspace is ${workspace}"

    local jobName=""
    local file=""

    local downStreamprojectsFile=$(createTempFile)
    runOnMaster ${LFS_CI_PATH}/bin/getDownStreamProjects -j ${JENKINS_JOB_NAME} -b ${BUILD_NUMBER} -h ${JENKINS_HOME} > ${downStreamprojectsFile}
    if [[ $? -ne 0 ]] ; then
        error "error in getDownStreamProjects for ${JENKINS_JOB_NAME} #${BUILD_NUMBER}"
        exit 1
    fi
    local triggeredJobData=$( cat ${downStreamprojectsFile} )

    trace "triggered job names are: ${triggeredJobNames}"
    execute mkdir -p ${workspace}/bld/

    for jobData in ${triggeredJobData} ; do

        local buildNumber=$(echo ${jobData} | cut -d: -f 1)
        local jobResult=$(  echo ${jobData} | cut -d: -f 2)
        local jobName=$(    echo ${jobData} | cut -d: -f 3-)

        trace "jobName ${jobName} buildNumber ${buildNumber} jobResult ${jobResult}"

        [[ ${jobResult} != "SUCCESS" ]] && error "downstream job ${jobName} was not successfull"

        info "copy artifacts from job ${jobName}#${buildNumber} to workspace and untarring it"

        local artifactsPathOnMaster=${artifactesShare}/${jobName}/${buildNumber}/save/

        execute rsync --archive --verbose --rsh=ssh -P                    \
            ${jenkinsMasterServerHostName}:${artifactsPathOnMaster}/ \
            ${workspace}/bld/

        for file in ${workspace}/bld/*
        do
            [[ -f ${file} ]] || continue

            trace "untar ${file} from job ${jobName}"
            execute tar --directory ${workspace}/bld/ --extract --xz --file ${file}  
            execute rm -f ${file}
        done
    done

    return 0
}

## @fn      _build()
#  @brief   make the build
#  @details make the real build. The required build targets / configs will be determinates by
#           sortbuildsfromdependencies. This creates a list with subsystems - configs in the
#           correct order. After this, it calls the build script and executes the build.
#  @todo    replace the sortbuildsfromdependencies with the new implemtation,
#           introduce the new syntax for sortbuildsfromdependencies.
#  @param   <none>
#  @return  <none>
_build() {
    local cfgFile=$(createTempFile)

    local location=$(getLocationName) 
    mustHaveLocationName

    local target=$(getTargetBoardName) 
    mustHaveTargetBoardName

    sortbuildsfromdependencies ${target} > ${cfgFile}
    rawDebug ${cfgFile}

    local amountOfTargets=$(wc -l ${cfgFile} | cut -d" " -f1)
    local counter=0

    while read SRC CFG
    do
        counter=$( expr ${counter} + 1 )
        info "(${counter}/${amountOfTargets}) building ${CFG} from ${SRC}..."
        execute build -C ${SRC} ${CFG} GZIPLEVEL=1
    done <${cfgFile}

    return 0
}

## @fn      _createArtifactArchive()
#  @brief   create the build artifacts archives and copy them to the share on the master server
#  @details the build artifacts are not handled by jenkins. we are doing it by ourself, because
#           jenkins can not handle artifacts on nfs via slaves very well.
#           so we create a tarball of each bld/* directory. this tarball will be moved to the master
#           on the /build share. Jenkins will see the artifacts, because we creating a link from
#           the build share to the jenkins build directory
#  @param   <none>
#  @return  <none>
_createArtifactArchive() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    # TODO: demx2fk3 2014-03-31 remove cd - dont change the current directory
    cd "${workspace}/bld/"

    local artifactsPathOnShare=${artifactesShare}/${JENKINS_JOB_NAME}/${BUILD_NUMBER}
    local artifactsPathOnMaster=${jenkinsMasterServerPath}/jobs/${JENKINS_JOB_NAME}/builds/${BUILD_NUMBER}/archive
    executeOnMaster mkdir -p  ${artifactsPathOnShare}/save
    executeOnMaster ln    -sf ${artifactsPathOnShare}      ${artifactsPathOnMaster}

    for dir in bld-* ; do
        [[ -d "${dir}" && ! -L "${dir}" ]] || continue
        info "creating artifact archive for ${dir}"
        execute tar --create --xz --file "${dir}.tar.xz" "${dir}"
        execute rsync --archive --verbose --rsh=ssh -P                  \
            "${dir}.tar.xz"                                             \
            ${jenkinsMasterServerHostName}:${artifactsPathOnShare}/save
    done

    return 0
}


## @fn      _createWorkspace()
#  @brief   create a new workspace for the project
#  @details this method is very huge. It creates a new workspace for a projects.
#           this includes several steps:
#           * create a new directory                             (build setup)
#           * cleanup the old workspace if exists   
#           * switch to the correct location (aka branch)        (build newlocations)
#           * copy build artifacts from the upstream project if exists
#           * apply patches to the workspace
#           * get the list of required subsystem
#           * check out the subsystem from svn                   (build adddir)
#  @param   <none>
#  @return  <none>
_createWorkspace() {

    local location=$(getLocationName) 
    mustHaveLocationName

    local target=$(getTargetBoardName) 
    mustHaveTargetBoardName

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    local taskName=$(getTaskNameFromJobName)
    local subTaskName=$(getSubTaskNameFromJobName)
    trace "taskName is ${taskName} / ${subTaskName}"
    debug "create workspace for ${location} / ${target} in ${workspace}"

    local build="build -W \"${workspace}\""

    debug "creating a new workspace in \"${workspace}\""
    setupNewWorkspace

    switchToNewLocation ${location}

    if grep -q "ulm" <<< ${NODE_LABELS} ; then
        # change from svne1 to ulmscmi
        switchSvnServerInLocations
    fi

    mustHaveValidWorkspace

    local srcDirectory=$(getConfig "subsystem")
    if [[ ! "${srcDirectory}" ]] ; then
        error "no srcDirectory found (subsystem)"
        exit 1;
    fi
    info "requested source directory: ${srcDirectory}"

    if grep -q "ulm" <<< ${NODE_LABELS} ; then
        preCheckoutPatchWorkspace
    fi

    info "getting dependencies for ${srcDirectory}"
    local buildTargets=$(${LFS_CI_PATH}/bin/getDependencies ${srcDirectory} 2>/dev/null )
    if [[ ! "${buildTargets}" ]] ; then
        error "no build targets configured"
        exit 1;
    fi

    buildTargets="$(getConfig additionalSourceDirectories) ${buildTargets}"

    local revision=
    if [[ ${JENKINS_SVN_REVISION} ]] ; then
        info "using subversion revision: ${JENKINS_SVN_REVISION}"
        revision=${JENKINS_SVN_REVISION}
    fi

    info "using src-dirs: ${buildTargets}"
            
    local amountOfTargets=$(echo ${buildTargets} | wc -w)
    local counter=0

    for src in ${buildTargets} ; do

        counter=$( expr ${counter} + 1 )
        info "(${counter}/${amountOfTargets}) checking out sources for ${src}"
        checkoutSubprojectDirectories "${src}" "${revision}"

    done

    mustHaveLocalSdks
    mustHaveBuildArtifactsFromUpstream

    postCheckoutPatchWorkspace

    return 0
}

## @fn      postCheckoutPatchWorkspace()
#  @brief   apply patches before the checkout of the workspace to the workspace
#  @param   <none>
#  @return  <none>
preCheckoutPatchWorkspace() {
    _applyPatchesInWorkspace "${JENKINS_JOB_NAME}/preCheckout/"
    _applyPatchesInWorkspace "common/preCheckout/"
    return
}

## @fn      postCheckoutPatchWorkspace()
#  @brief   apply patches after the checkout of the workspace to the workspace
#  @param   <none>
#  @return  <none>
postCheckoutPatchWorkspace() {
    _applyPatchesInWorkspace "${JENKINS_JOB_NAME}/postCheckout/"
    _applyPatchesInWorkspace "common/postCheckout/"
    return
}

## @fn      _applyPatchesInWorkspace()
#  @brief   apply patches to the workspace, if exist one for the directory
#  @details in some cases, it's required to apply a patch to the workspace to
#           change some "small" issue in the workspace, e.g. change the svn server
#           from the master svne1 server to the slave ulisop01 server.
#  @param   <none>
#  @return  <none>
_applyPatchesInWorkspace() {

    local patchPath=$@

    if [[ -d "${LFS_CI_PATH}/patches/${patchPath}" ]] ; then
        for patch in "${LFS_CI_PATH}/patches/${patchPath}/"* ; do
            [[ ! -f "${patch}" ]] && continue
            info "applying post checkout patch $(basename \"${patch}\")"
            patch -p0 < "${patch}" || exit 1
        done
    fi

    return
}

## @fn      getConfig( key )
#  @brief   get the configuration to the requested key
#  @details �full description�
#  @todo    move this into a generic module. make it also more configureable
#  @param   {key}    key name of the requested value
#  @return  value for the key
getConfig() {
    local key=$1

    trace "get config value for ${key}"

    taskName=$(getTaskNameFromJobName)
    subTaskName=$(getSubTaskNameFromJobName)
    location=$(getLocationName)
    config=$(getTargetBoardName)

    case "${key}" in 
        subsystem)
            case "${subTaskName}" in
                FSM-r2       ) echo src-psl    ;;
                FSM-r2-rootfs) echo src-rfs    ;;
                FSM-r3)        echo src-fsmpsl ;;
                LRC)           echo src-lrcpsl ;;
                UBOOT)         echo src-fsmbrm ;;
            esac
        ;;
        locationMapping)
            case "${subTaskName}" in
                LRC)    echo LRC         ;;
                UBOOT)  echo nightly     ;;
                FSM-r3) echo ${location} ;;
            esac
        ;;
        additionalSourceDirectories)
            case "${subTaskName}" in
                LRC)    echo src-lrcbrm src-cvmxsources src-kernelsources src-bos src-lrcddg src-ifdd src-commonddal src-lrcddal src-tools src-rfs src-toolset ;;
            esac
        ;;
        *) : ;;
    esac
}

## @fn      synchroniceToLocalPath( localPath )
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

    local localCacheDir=${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/${subsystem}

    if [[ ! -e ${localCacheDir}/${tag} ]] ; then
        progressFile=${localCacheDir}/data/${tag}.in_progress

        if [[ ! -e ${progressFile} ]] ; then

            info "synchronice ${subsystem}/${tag} to local filesystem"

            execute mkdir -p ${localCacheDir}/data
            execute touch ${progressFile}

            execute rsync --archive --numeric-ids --delete-excluded --ignore-errors \
                --hard-links --sparse --exclude=.svn --rsh=ssh                      \
                ${jenkinsMasterServerHostName}:${remotePath}/                       \
                ${localCacheDir}/data/${tag}/                    

            execute ln -sf data/${tag} ${localCacheDir}/${tag}
            execute rm -f ${progressFile}
        else
            info "waiting for ${tag} on local filesystem"
            # 2014-03-12 demx2fk3 TODO make this configurable
            sleep 60
            synchroniceToLocalPath ${localPath}
        fi
    fi

    return
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
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    debug "checking for links in bld" 

    for bld in ${workspace}/bld/*
    do
        [[ -e ${bld} ]] || continue
        local pathToSdk=$(readlink ${bld})
        local tag=$(basename ${pathToSdk})
        local subsystem=$(basename ${bld})
        local localCacheDir=${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/${subsystem}

        info "checking for ${subsystem} / ${tag} on local disk"
        
        if [[ ! -d ${localCacheDir}/${tag} ]] ; then
            synchroniceToLocalPath ${bld}
        fi

        execute rm -rf ${bld} 
        execute ln -sf ${localCacheDir}/${tag} ${bld}
    done

    return
}

## @fn      mustHaveBuildArtifactsFromUpstream()
#  @brief   ensure, that the job has the artifacts from the upstream projekt, if exists
#  @detail  the method check, if there is a upstream project is set and if this project has
#           artifacts. If this is true, it copies the artifacts to the workspace bld directory
#           and untar the artifacts.
#  @param   <none>
#  @return  <none>
mustHaveBuildArtifactsFromUpstream() {

    local workspace=$(getWorkspaceName)

    debug "checking for build artifacts on share of upstream project"

    if [[ -d ${artifactesShare}/${UPSTREAM_PROJECT}/${UPSTREAM_BUILD}/save/ ]] ; then
        info "copy artifacts of ${UPSTREAM_PROJECT} #${UPSTREAM_BUILD} from master"
        execute mkdir -p ${workspace}/bld/
        execute rsync --archive --verbose -P --rsh=ssh                                                     \
            ${jenkinsMasterServerHostName}:${artifactesShare}/${UPSTREAM_PROJECT}/${UPSTREAM_BUILD}/save/. \
            ${workspace}/bld/.

        for file in ${workspace}/bld/*.tar.xz
        do
            [[ -f ${file} ]] || continue
            info "untaring build artifacts ${file}"
            execute tar -C ${workspace}/bld/ --extract --xz --file ${file}
        done
    fi

    return
}

return 0
