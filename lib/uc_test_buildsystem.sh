#!/bin/bash


# LFS_Post_-_trunk_-_TestBuildsystem_-_Dependencies_Ulm

ci_job_test_buildsystem() {

    requiredParameters     

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    warning "work in progress..."
    exit 0
#    cd ${workspace}
#    build setup
#    build newlocations
#    build adddir src-test
#
#    make -C ... test (xml output)
#    cp *.xml ...

    return

}
