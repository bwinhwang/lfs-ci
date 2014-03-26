#!/bin/bash


## @fn      ci_job_build()
#  @brief   create a build
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

ci_job_package() {
    info "package the build results"
# TRIGGERED_BUILD_RUN_COUNT_LFS_CI_trunk_Build_LRC_lcpa=1
# TRIGGERED_BUILD_NUMBER_LFS_CI_trunk_Build_FSM_r3_qemu_64=1
# TRIGGERED_JOB_NAMES=LFS_CI_trunk_Build_FSM_r2_qemu,LFS_CI_trunk_Build_LRC_lcpa,LFS_CI_trunk_Build_FSM_r2_fcmd,LFS_CI_trunk_Build_UBOOT_fcta,LFS_CI_tr

    local oldIFS=${IFS}
    local jobName=""
    for ${jobName} in ${TRIGGERED_JOB_NAMES} ; do
        local varName=TRIGGERED_BUILD_NUMBER_${jobName}
        ls -la /build/home/demx2fk3/lfs/${jobName}/${$varName}/
    done
    IFS=${oldIFS}

    return 0
}

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
        execute build -C ${SRC} ${CFG}
    done <${cfgFile}

    return 0
}

_createArtifactArchive() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    cd "${workspace}/bld/"
    execute mkdir -p /build/home/demx2fk3/lfs/${JENKINS_JOB_NAME}/${BUILD_NUMBER}
    for dir in bld-* ; do
        [[ -d "${dir}" && ! -L "${dir}" ]] || continue
        info "creating artifact archive for ${dir}"
        execute tar -c -z -f "${dir}.tar.gz" "${dir}"
        execute rsync -avrPe ssh "${dir}.tar.gz" maxi.emea.nsn-net.net:/build/home/demx2fk3/lfs/${JENKINS_JOB_NAME}/${BUILD_NUMBER}/
        execute ssh maxi.emea.nsn-net.net ln -s /build/home/demx2fk3/lfs/${JENKINS_JOB_NAME}/${BUILD_NUMBER} /var/fpwork/demx2fk3/lfs-jenkins/home/jobs/${JENKINS_JOB_NAME}/archive/save
    done

    return 0
}

## @fn      _createWorkspace()
#  @brief   create a workspace
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

    postCheckoutPatchWorkspace

    return 0
}

preCheckoutPatchWorkspace() {
    _applyPatchesInWorkspace "${JENKINS_JOB_NAME}/preCheckout/"
    _applyPatchesInWorkspace "common/preCheckout/"
    return
}

postCheckoutPatchWorkspace() {
    _applyPatchesInWorkspace "${JENKINS_JOB_NAME}/postCheckout/"
    _applyPatchesInWorkspace "common/postCheckout/"
    return
}

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
                FSM-r2) echo src-psl    ;;
                FSM-r3) echo src-fsmpsl ;;
                LRC)    echo src-lrcpsl ;;
                UBOOT)  echo src-fsmbrm ;;
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

syncroniceToLocalPath() {
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

            execute rsync -a --numeric-ids --delete-excluded --ignore-errors -H -S \
                        --exclude=.svn                                     \
                        ${remotePath}/                                     \
                        ${localCacheDir}/data/${tag}/                    

            execute ln -sf data/${tag} ${localCacheDir}/${tag}
            execute rm -f ${progressFile}
        else
            info "waiting for ${tag} on local filesystem"
            # 2014-03-12 demx2fk3 TODO make this configurable
            sleep 60
            syncroniceToLocalPath ${localPath}
        fi
    fi

    return
}

mustHaveLocalSdks() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    for bld in ${workspace}/bld/*
    do
        local pathToSdk=$(readlink ${bld})
        local tag=$(basename ${pathToSdk})
        local subsystem=$(basename ${bld})
        local localCacheDir=${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/${subsystem}

        info "checking for ${subsystem} on local disk"
        
        if [[ ! -d ${localCacheDir} ]] ; then
            syncroniceToLocalPath ${bld}
        fi

        execute rm -rf ${bld} 
        execute ln -sf ${localCacheDir}/${tag} ${bld}
    done

    return
}

return 0
