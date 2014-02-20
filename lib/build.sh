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

    info "build done."

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
    mustHaveLocationName

    local grepMinusV=$(getConfig "platformTargets_${location}_${target}")
    sortbuildsfromdependencies | grep -v -e ftlb ${grepMinusV} > ${cfgFile}

    local amountOfTargets=$(wc -l ${cfgFile} | cut -d" " -f1)
    local counter=0

    while read SRC CFG
    do
        counter=$( expr ${counter} + 1 )
        info "building (${counter}/${amountOfTargets}) ${CFG} from ${SRC}..."
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
    mustHaveLocationName

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

    local buildTargets=$(getConfig "buildTargets_${location}_${target}")
    if [[ ! "${buildTargets}" ]] ; then
        error "no build targets configured"
        exit 1;
    fi

    preCheckoutPatchWorkspace
            
    for src in $(getConfig "buildTargets_${location}_${target}") ; do

        info "checking out sources for ${src}"
        checkoutSubprojectDirectories "${src}"

    done

    postCheckoutPatchWorkspace

    return 0
}

preCheckoutPatchWorkspace() {
    if [[ -d "${CI_PATH}/patches/${JENKINS_JOB_NAME}/preCheckout/" ]] ; then
        for patch in "${CI_PATH}/patches/${JENKINS_JOB_NAME}/preCheckout/"* ; do
            [[ ! -f "${patch}" ]] && continue
            info "applying pre checkout patch $(basename \"${patch}\")"
            patch -p0 < "${patch}" || exit 1
        done
    fi
}

postCheckoutPatchWorkspace() {
    if [[ -d "${CI_PATH}/patches/${JENKINS_JOB_NAME}/postCheckout/" ]] ; then
        for patch in "${CI_PATH}/patches/${JENKINS_JOB_NAME}/postCheckout/"* ; do
            [[ ! -f "${patch}" ]] && continue
            info "applying post checkout patch $(basename \"${patch}\")"
            patch -p0 < "${patch}" || exit 1
        done
    fi
}


getConfig() {
    local key=$1

    trace "get config value for ${key}"
    case "${key}" in 
        buildTargets_pronb-developer_fspc)    echo src-cvmxsources src-kernelsources src-fsmbos ;;
        buildTargets_pronb-developer_fcmd)    echo src-cvmxsources src-kernelsources src-fsmbos ;;
        buildTargets_pronb-developer_fct)     echo src-cvmxsources src-kernelsources src-fsmbrm src-fsmbos src-fsmddg src-fsmdtg src-fsmifdd src-fsmddal src-fsmfmon src-fsmrfs src-fsmpsl src-fsmwbit ;;
        buildTargets_pronb-developer_qemu)    echo src-cvmxsources src-kernelsources src-fsmbrm src-fsmbos src-fsmddg src-fsmdtg src-fsmifdd src-fsmddal src-fsmfmon src-fsmrfs src-fsmpsl src-fsmwbit ;;
        buildTargets_pronb-developer_octeon2) echo src-cvmxsources src-kernelsources src-fsmbrm src-fsmbos src-fsmddg src-fsmdtg src-fsmifdd src-fsmddal src-fsmfmon src-fsmrfs src-fsmpsl src-fsmwbit ;;
        platformTargets_pronb-developer_fct)     echo "-e octeon -e x86_64 -e ftlb -e qemu -e fcmd -e fspc       " ;;
        platformTargets_pronb-developer_fspc)    echo "-e octeon -e x86_64 -e ftlb -e qemu -e fcmd         -e fct" ;;
        platformTargets_pronb-developer_fcmd)    echo "-e octeon -e x86_64 -e ftlb -e qemu         -e fspc -e fct" ;;
        platformTargets_pronb-developer_qemu)    echo "-e octeon           -e ftlb         -e fcmd -e fspc -e fct" ;;
        platformTargets_pronb-developer_octeon2) echo "          -e x86_64 -e ftlb -e qemu -e fcmd -e fspc -e fct" ;;
        *) : ;;
    esac

}

return 0
