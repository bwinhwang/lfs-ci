#!/bin/bash



ci_job_build() {

    info "creating the workspace..."


    _createWorkspace

    info "building targets..."

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

    debug "workspace is \"${workspace}\""


    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    execute cd "${workspace}"
    echo ${PWD}

    execute build setup

    # execute build newlocation ${location}

}

return 0
