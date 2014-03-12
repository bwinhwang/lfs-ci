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

_build() {
    local cfgFile=$(createTempFile)

    local location=$(getLocationName) 
    mustHaveLocationName

    local target=$(getTargetBoardName) 
    mustHaveTargetBoardName

    local grepMinusV=$(getConfig "platformTargets_${location}_${target}")
    sortbuildsfromdependencies ${target} | grep -v -e ftlb ${grepMinusV} > ${cfgFile}

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
    for dir in bld-* ; do
        [[ -d "${dir}" && ! -L "${dir}" ]] || continue
        info "creating artifact archive for ${dir}"
        execute tar -c -z -f "${dir}.tar.gz" "${dir}"
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

    debug "create workspace for ${location} / ${target} in ${workspace}"

    local build="build -W \"${workspace}\""

    debug "ceating a new workspace in \"${workspace}\""
    setupNewWorkspace

    # change from svne1 to ulmscmi
    switchSvnServerInLocations

    switchToNewLocation

    mustHaveValidWorkspace

    local srcDirectory=$(getConfig "buildTargets_${location}_${target}")
    if [[ ! "${srcDirectory}" ]] ; then
        error "no srcDirectory found (buildTargets_${location}_${target})"
        exit 1;
    fi
    info "requested source directory: ${srcDirectory}"

    preCheckoutPatchWorkspace

    info "getting dependencies for ${srcDirectory}"
    local buildTargets=$(${CI_PATH}/bin/getDependencies ${srcDirectory} 2>/dev/null )
    if [[ ! "${buildTargets}" ]] ; then
        error "no build targets configured"
        exit 1;
    fi

    local revision=
    if [[ ${JENKINS_SVN_REVISION} ]] ; then
        info "using subversion revision: ${JENKINS_SVN_REVISION}"
        revision=${JENKINS_SVN_REVISION}
    fi

    info "using src-dirs: ${buildTargets}"
            
    local amountOfTargets=$(echo ${buildTargets} ${srcDirectory} | wc -w)
    local counter=0

    for src in ${buildTargets} ${srcDirectory} ; do

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
}

postCheckoutPatchWorkspace() {
    _applyPatchesInWorkspace "${JENKINS_JOB_NAME}/postCheckout/"
    _applyPatchesInWorkspace "common/postCheckout/"
}

_applyPatchesInWorkspace() {

    local patchPath=$@

    if [[ -d "${CI_PATH}/patches/${patchPath}" ]] ; then
        for patch in "${CI_PATH}/patches/${patchPath}/"* ; do
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
    case "${key}" in 
        buildTargets_pronb-developer_fspc)        echo src-psl ;;
        buildTargets_pronb-developer_fcmd)        echo src-psl ;;
        buildTargets_pronb-developer_qemu_x86)    echo src-psl ;;

        buildTargets_pronb-developer_fsp)         echo src-fsmpsl ;;
        buildTargets_pronb-developer_fct)         echo src-fsmpsl ;;
        buildTargets_pronb-developer_qemu_x86_64) echo src-fsmpsl ;;
        buildTargets_pronb-developer_octeon2)     echo src-fsmpsl ;;
        buildTargets_pronb-developer_lcpa)        echo src-fsmpsl ;;

        platformTargets_pronb-developer_fct)         echo "-e octeon -e qemu_x86_64 -e ftlb -e qemu_i386 -e _x86 -e fcmd -e fspc       " ;;
        platformTargets_pronb-developer_fspc)        echo "-e octeon -e qemu_x86_64 -e ftlb -e qemu_i386 -e _x86 -e fcmd         -e fct" ;;
        platformTargets_pronb-developer_fcmd)        echo "-e octeon -e qemu_x86_64 -e ftlb -e qemu_i386 -e _x86         -e fspc -e fct" ;;
        platformTargets_pronb-developer_qemu_x86)    echo "-e octeon -e qemu_x86_64 -e ftlb              -e _x86 -e fcmd -e fspc -e fct" ;;
        platformTargets_pronb-developer_qemu_x86_64) echo "-e octeon                -e ftlb -e qemu_i386         -e fcmd -e fspc -e fct" ;;
        platformTargets_pronb-developer_octeon2)     echo "          -e qemu_x86_64 -e ftlb -e qemu_i386 -e _x86 -e fcmd -e fspc -e fct" ;;
        *) : ;;
    esac

}

syncroniceSdkToLocalPath() {
    local sdk=$1
    local tag=$(basename ${sdk})

    export LOCAL_SDK_PATH=/var/fpwork/${USER}/lfs-local-sdks/
    if [[ ! -e ${LOCAL_SDK_PATH}/${tag} ]] ; then
        progressFile=${LOCAL_SDK_PATH}/data/${tag}.in_progress

        if [[ ! -e ${progressFile} ]] ; then

            info "synchronice sdk ${tag} to local filesystem"

            mkdir -p ${LOCAL_SDK_PATH}/data
            touch ${progressFile}

            rsync -a --numeric-ids --delete-excluded --ignore-errors -H -S \
                        --exclude=.svn                                     \
                        ${sdk}/.                                           \
                        ${LOCAL_SDK_PATH}/data/${tag}/                     || exit 1

            ln -sf ${LOCAL_SDK_PATH}/data/${tag} ${LOCAL_SDK_PATH}/${tag}
            rm -f ${progressFile}
        else
            info "waiting for ${tag} on local filesystem"
            sleep 300
            syncroniceSdkToLocalPath ${sdk}
        fi
    fi

}

mustHaveLocalSdks() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    export LOCAL_SDK_PATH=/var/fpwork/${USER}/lfs-local-sdks/
    for sdk in ${workspace}/bld/sdk* 
    do
        local pathToSdk=$(readlink ${sdk})
        local tag=$(basename ${pathToSdk})
        
        if [[ ! -d ${LOCAL_SDK_PATH}/${tag} ]] ; then
            syncroniceSdkToLocalPath ${pathToSdk}
        fi

        rm -rf ${sdk} 
        ln -sf ${LOCAL_SDK_PATH}/${tag} ${sdk}
    done

}
return 0
