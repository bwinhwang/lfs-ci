#!/bin/bash

source test/common.sh

oneTimeSetUp() {
    return
}
oneTimeTearDown() {
    return
}
tearDown() {
    unset UPSTREAM_BUILD
    unset UPSTREAM_PROJECT
    unset OLD_REVISION_STATE_FILE
    unset CHANGELOG
    unset JOB_NAME
    unset BUILD_NUMBER
}
setUp() {
    export LFS_CI_GLOBAL_BRANCH_NAME=trunk

    case ${_shunit_test_} in
        test1)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
        ;;
        test2)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_job_name\n1" > ${OLD_REVISION_STATE_FILE}

            export JOB_NAME=job_name
            export BUILD_NUMBER=3

            export UPSTREAM_PROJECT=upstream_job_name
            export UPSTREAM_BUILD=3
        ;;
        test3)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_job_name\n1" > ${OLD_REVISION_STATE_FILE}

            export JOB_NAME=job_name
            export BUILD_NUMBER=3
        ;;
        test4)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_job_name\n1" > ${OLD_REVISION_STATE_FILE}

            export JOB_NAME=job_name
            export BUILD_NUMBER=2
            export UPSTREAM_PROJECT=upstream_job_name
            export UPSTREAM_BUILD=1
        ;;
        test5)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
            echo -e "other_upstream_project_name\n1" > ${OLD_REVISION_STATE_FILE}

            export JOB_NAME=job_name
            export BUILD_NUMBER=2
            export UPSTREAM_PROJECT=upstream_job_name
            export UPSTREAM_BUILD=1
        ;;
    esac

    export JEKINS_HOME=$(createTempDirectory)
    mkdir -p ${JEKINS_HOME}/jobs/upstream_job_name/builds/3
    cp -a ${LFS_CI_ROOT}/test/data/10_customSCM.upstream_changelog_3.xml \
            ${JEKINS_HOME}/jobs/upstream_job_name/builds/3/changelog.xml
    ln -sf 3 ${JEKINS_HOME}/jobs/upstream_job_name/builds/lastSuccessfulBuild


    mkdir -p ${JEKINS_HOME}/jobs/upstream_job_name/builds/2
    cp -a ${LFS_CI_ROOT}/test/data/10_customSCM.upstream_changelog_2.xml \
            ${JEKINS_HOME}/jobs/upstream_job_name/builds/2/changelog.xml

    export LFS_CI_CONFIG_FILE=$(createTempFile)
    echo 'jenkinsMasterServerHostName=localhost'            >  ${LFS_CI_CONFIG_FILE}
    echo 'jenkinsMasterServerPath = ${JEKINS_HOME}'         >> ${LFS_CI_CONFIG_FILE}
    echo 'CUSTOM_SCM_upstream_job_name = upstream_job_name' >> ${LFS_CI_CONFIG_FILE}

    return
}

test1() {
    assertTrue "first build of a branch / job => no old data available" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"
}
test2() {
    assertTrue "normal run, get changelog" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"

    assertExecutedCommands ${CHANGELOG} ${LFS_CI_ROOT}/test/data/10_customSCM.upstream_test2_expected_changelog.xml
}

test3() {
    assertTrue "build triggered by hand" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"

    assertExecutedCommands ${CHANGELOG} ${LFS_CI_ROOT}/test/data/10_customSCM.upstream_test2_expected_changelog.xml
}

test4() {
    assertTrue "rebuild without change in upstream" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"

    local expected=$(createTempFile)
    echo -n "<log/>" > ${expected}
    assertExecutedCommands ${CHANGELOG} ${expected}
}

test5() {
    assertFalse "something wrong: project name are different" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"
}

# test6() {
#     assertFalse "something wrong: project name are different" \
#         "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"
# }
source lib/shunit2

exit 0

