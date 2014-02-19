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

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local build="build -W \"${workspace}\""
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    debug "ceating a new workspace in \"${workspace}\""
    setupNewWorkspace

    # change from svne1 to ulmscmi
    switchSvnServerInLocations

    switchToNewLocation

    mustHaveValidWorkspace

    for src in $(getConfig buildTargets_${location}_${target}) ; do

        checkoutSubprojectDirectories ${src}

    done

    return 0
}

return 0
