#!/bin/bash
## @file    uc_test_unittest_ddal.sh
#  @brief   the unittest ddal usecase
#  @details job name: LFS_CI_-_trunk_-_Unittest_-_FSM-r3_-_fsm3_octeon2_-_ddal

[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ci_job_test_unittest_ddal()
#  @brief   create a workspace and run the unit tests for ddal
#  @todo    lot of pathes are hardcoded at the moment. make this more configureable
#  @param   <none>
#  @return  <none>
ci_job_test_unittest_ddal() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD JOB_NAME BUILD_NUMBER WORKSPACE

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    createOrUpdateWorkspace --allowUpdate

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

    local revision=$(latestRevisionFromRevisionStateFile)
    mustHaveValue "${revision}" "revision"

    checkoutSubprojectDirectories src-unittests ${revision}

    execute cd ${workspace}/src-unittests/src/tests/ddal/runtests

    info "creating testconfig"
    execute make testconfig-overwrite TESTBUILD=${workspace} TESTTARGET=localhost-x86

    info "running test suite.."
    execute make clean
    execute -i make -i test-xmloutput JOB_NAME="$JOB_NAME"

    case "$JOB_NAME"
    in *FSM-r4*) TARGET_TYPE=FSM-r4
    ;; *)        TARGET_TYPE=FSM-r3
    esac

    case "$JOB_NAME"
    in *valgrind*) VALGRIND_STR=" Valgrind"
    ;; *)          VALGRIND_STR=
    esac

    local src=src-unittests/src/tests/ddal/ddal-unittests

    info "collecting results"
    execute rm -rf ${workspace}/xml-reports
    execute mkdir ${workspace}/xml-reports
    execute -n find ${workspace}/${src} -name xml-reports \
        | while read name ; do
            local destination=$(sed -e "s:^${src}::" <<< ${name})
            execute cp -f ${name}/* ${workspace}/xml-reports
        done

    cd ${workspace}
    local mergexmltestcases=${workspace}/src-test/src/bin/mergexmltestcases
    mustExistFile ${mergexmltestcases}
    local mergeresult=testcases.merged.xml
    execute -n ${mergexmltestcases} > ${mergeresult}
    execute gzip -6 -f ${mergeresult}

    mustExistFile ${mergeresult}.gz
    copyFileToArtifactDirectory ${mergeresult}.gz
    copySonarFileToUserContentDirectory ${mergeresult}.gz ${TARGET_TYPE}

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

    execute -n find . -name '*.html' | execute xargs -n1 sed -i -e "s/LCOV -/${label} $TARGET_TYPE$VALGRIND_STR DDAL Unittests -/"
    execute -n ${lcov} --summary lcov.out > lcov.summary

    rawDebug lcov.summary

    mustExistFile coverage.xml
    execute gzip -6 -f coverage.xml
    copyFileToArtifactDirectory coverage.xml.gz
    copySonarFileToUserContentDirectory coverage.xml.gz ${TARGET_TYPE}

    # TODO: demx2fk3 2015-01-23 make this in a function
    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
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

    databaseTestResults ${label}      \
                        unittest_ddal \
                        localhost-x86 \
                        $TARGET_TYPE  \
                        ${resultFile}

    info "testing done."

    return
}
