#!/bin/bash

#
# LFS_CI_-_trunk_-_Unittest_-_FSM-r3_-_fsm3_octeon2_-_ddal
#

[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ci_job_test_unittest()
#  @brief   create a workspace and run the unit tests for ddal
#  @todo    lot of pathes are hardcoded at the moment. make this more configureable
#  @param   <none>
#  @return  <none>
ci_job_test_unittest() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    createOrUpdateWorkspace --allowUpdate

    copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} properties 
    mustExistFile ${WORKSPACE}/properties
    rawDebug ${WORKSPACE}/properties

    source ${WORKSPACE}/properties

    local revision=$(latestRevisionFromRevisionStateFile)
    mustHaveValue "${revision}" "revision"

    checkoutSubprojectDirectories src-unittests ${revision}

    execute cd ${workspace}/src-unittests/src/tests/ddal/runtests

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
    local lcov_cobertura=${workspace}/src-unittests/src/frameworks/lcov_cobertura/bin/lcov_cobertura.py
    mustExistFile ${lcov_cobertura}

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
    execute python ${lcov_cobertura} lcov.out
    execute sed -i -e 's/#FFFFFF/#FFFFEE/' gcov.css

    execute -n find . -name '*.html' | execute xargs -n1 sed -i -e "s/LCOV -/${LABEL} DDAL Unittests -/"
    execute -n ${lcov} --summary lcov.out > lcov.summary

    rawDebug lcov.summary

    mustExistFile coverage.xml
    copyFileToArtifactDirectory coverage.xml

    # TODO: demx2fk3 2015-01-23 make this in a function
    local artifactsPathOnShare=$(getConfig artifactesShare)/${jobName}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}/save

    # TODO add data to database
    set -- $(grep 'lines.*: ' lcov.summary | sed -e 's/[()%]//g')
    local LINES_COVERED=$3
    local LINES_TOTAL=$5
    set -- $(grep 'functions.*: ' lcov.summary | sed -e 's/[()%]//g')
    local FUNCTIONS_COVERED=$3
    local FUNCTIONS_TOTAL=$5

    local resultFile=$(createTempFile)
    echo "lines_covered;${LINES_COVERED}"          > ${resultFile}
    echo "lines_total;${LINES_TOTAL}"             >> ${resultFile}
    echo "functions_covered;${FUNCTIONS_COVERED}" >> ${resultFile}
    echo "functions_total;${FUNCTIONS_TOTAL}"     >> ${resultFile}

    databaseTestResults ${LABEL}      \
                        makingTest    \
                        localhost-x86 \
                        FSM-r3        \
                        ${resultFile}

    info "testing done."

    return
}
