#!/bin/bash

#
# LFS_CI_-_trunk_-_Unittest_-_FSM-r3_-_fsm3_octeon2
#

[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

ci_job_test_unittest() {

    export JOB_NAME=LFS_CI_-_trunk_-_Unittest_-_FSM-r3_-_fsm3_octeon2

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    createOrUpdateWorkspace --allowUpdate

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    local revision=$(latestRevisionFromRevisionStateFile)
    mustHaveValue "${revision}" "revision"

    checkoutSubprojectDirectories src-unittests ${revision}

    cd ${workspace}/src-unittests/src/tests/ddal/runtests

    info "creating testconfig"
    execute make testconfig-overwrite TESTBUILD=${workspace} TESTTARGET=localhost-x86

    info "running test suite.."
    execute make clean
    execute -i make -i test-xmloutput

    local src=src-unittests/src/tests/ddal/ddal-unittests

    info "collecting results"
    execute rm -rf ${workspace}/xml-reports
    execute mkdir ${workspace}/xml-reports
    execute -n find ${workspace}/${src} -name xml-reports \
        | while read name ; do
            local destination=$(sed -e "s:^${src}::" <<< ${name})
            execute cp -f ${name}/* ${workspace}/xml-reports
        done


    local lcov=${workspace}/src-unittests/src/frameworks/lcov/bin/lcov
    mustExistFile ${lcov}
    local genHtml=${workspace}/src-unittests/src/frameworks/lcov/bin/genhtml
    mustExistFile ${genHtml}

    info "analysing results..."
    execute rm -rf ${workspace}/html
    execute mkdir ${workspace}/html

    cd ${workspace}/${src}/src-fsmddal/src/
    execute ${lcov} -c -i -d . -o ${workspace}/html/init.out
    execute ${lcov} -c    -d . -o ${workspace}/html/cov.out
    execute ${lcov} -a ${workspace}/html/init.out -a ${workspace}/html/cov.out \
            -o ${workspace}/html/lcovall.out
    execute ${lcov} -r ${workspace}/html/lcovall.out '/usr/include/*' -o ${workspace}/html/lcov.out

    cd ${workspace}/html
    execute ${genHtml} lcov.out
    execute sed -i -e 's/#FFFFFF/#FFFFEE/' gcov.css

    execute -n find . -name '*.html' | execute xargs -n1 sed -i -e "s/LCOV -/${label} DDAL Unittests -/"
    execute -n ${lcov} --summary lcov.out > lcov.summary

    rawDebug lcov.summary

    # TODO add data to database
    set -- $(grep 'lines.*: ' lcov.summary | sed -e 's/[()%]//g')
    local LINES_COVERED=$3
    local LINES_TOTAL=$5
    set -- $(grep 'functions.*: ' lcov.summary | sed -e 's/[()%]//g')
    local FUNCTIONS_COVERED=$3
    local FUNCTIONS_TOTAL=$5

    info "testing done."

    return
}
