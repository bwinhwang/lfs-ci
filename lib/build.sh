#!/bin/bash


## @fn      ci_job_build()
#  @brief   create a build
#  @param   <none>
#  @return  <none>
ci_job_build() {

    info "creating the workspace..."

    _createWorkspace

    info "building targets..."

    execute build -C src-fsmddal qemu_x86_64

    info "build done."

    info "upload results to artifakts share."

    info "build job finished."

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
    # mustHaveLocationName

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

    buildTargets=$(getConfig "buildTargets_${location}_${target}")
    if [[ ! "${buildTargets}" ]] ; then
        error "no build targets configured"
        exit 1;
    fi

            
    for src in $(getConfig "buildTargets_${location}_${target}") ; do

        info "checking out sources for ${src}"
        checkoutSubprojectDirectories "${src}"

    done

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
    if [[ -d "${CI_PATH}/patches/${JENKINS_JOB_NAME}/preCheckout/" ]] ; then
        for patch in "${CI_PATH}/patches/${JENKINS_JOB_NAME}/preCheckout/"* ; do
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
        buildTargets_pronb-developer_fct) echo src-cvmxsources src-kernelsources src-fsmbrm src-fsmbos src-fsmddg src-fsmdtg src-fsmifdd src-fsmddal src-fsmfmon src-fsmrfs src-fsmpsl src-fsmwbit ;;
        buildTargets_pronb-developer_qemu) echo src-cvmxsources src-kernelsources src-fsmbrm src-fsmbos src-fsmddg src-fsmdtg src-fsmifdd src-fsmddal src-fsmfmon src-fsmrfs src-fsmpsl src-fsmwbit ;;
        *) : ;;
    esac

}

return 0
