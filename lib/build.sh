#!/bin/bash



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


_createWorkspace() {

    local location=$(getLocationName) 
    mustHaveLocationName

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local build="build -W \"${workspace}\""

    debug "workspace is \"${workspace}\""

    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    setupNewWorkspace

    switchSvnServerInLocations

    switchToNewLocation

    mustHaveValidWorkspace

    checkoutSubprojectDirectories src-fsmddal

    return 0
}

return 0
