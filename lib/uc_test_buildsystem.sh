#!/bin/bash


# LFS_Post_-_trunk_-_TestBuildsystem_-_Dependencies_Ulm
source ${LFS_CI_ROOT}/lib/uc_build.sh

ci_job_test_buildsystem() {

    requiredParameters     

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    _createWorkspace

    local testSuiteDirectory=${workspace}/src-test/src/unittest/testsuites/buildsystem/dependencies

    execute make -C ${testSuiteDirectory} test-xmloutput
    execute mkdir ${workspace}/xml-reports/
    execute cp -f ${testSuiteDirectory}/xml-reports/*.xml ${workspace}/xml-reports/

    return
}
