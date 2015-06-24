#!/bin/bash
## @file  uc_test_buildsystem
#  @brief the test buildsystem usecase
#  @details job name : LFS_Post_-_trunk_-_TestBuildsystem_-_Dependencies_Ulm

[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

## @fn      ci_job_test_buildsystem()
#  @brief   test the build systems / dependency 
#  @param   <none>
#  @return  <none>
ci_job_test_buildsystem() {
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} label.txt

    local label=$(cat ${WORKSPACE}/label.txt)

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

    local svnReposUrl=$(getConfig LFS_PROD_svn_delivery_os_repos_url -t tagName:${label})
    mustExistInSubversion ${svnReposUrl}/tags/${label}/doc/scripts/ revisions.txt
    local revision=$(svnCat ${svnReposUrl}/tags/${label}/doc/scripts/revisions.txt | cut -d" " -f3 | sort -nu | tail -n 1)

    echo "src-foo http://fake/ ${revision}" > ${WORKSPACE}/revisions.txt

    createWorkspace

    local testSuiteDirectory=${workspace}/src-test/src/unittest/testsuites/buildsystem/dependencies


    info "starting tests..."
    execute make -C ${testSuiteDirectory} clean
    execute make -C ${testSuiteDirectory} testconfig-overwrite
    execute make -C ${testSuiteDirectory} test-xmloutput
    execute mkdir ${workspace}/xml-reports/
    execute cp -f ${testSuiteDirectory}/xml-reports/*.xml* ${workspace}/xml-reports/

    info "test done."

    return
}
