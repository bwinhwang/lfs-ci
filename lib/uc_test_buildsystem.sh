#!/bin/bash
# LFS_Post_-_trunk_-_TestBuildsystem_-_Dependencies_Ulm

[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

ci_job_test_buildsystem() {
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    createWorkspace

    local testSuiteDirectory=${workspace}/src-test/src/unittest/testsuites/buildsystem/dependencies

    execute make -C ${testSuiteDirectory} clean
    execute make -C ${testSuiteDirectory} test-xmloutput
    execute mkdir ${workspace}/xml-reports/
    execute cp -f ${testSuiteDirectory}/xml-reports/*.xml* ${workspace}/xml-reports/

    return
}
