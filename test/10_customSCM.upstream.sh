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
    unset TESTED_BUILD_NUMBER
    unset TESTED_BUILD_JOBNAME
}
setUp() {
    export LFS_CI_GLOBAL_BRANCH_NAME=trunk

    case ${_shunit_test_} in
        test1_checkout)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
        ;;
        test2_checkout)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_job_name\n1" > ${OLD_REVISION_STATE_FILE}

            export JOB_NAME=job_name
            export BUILD_NUMBER=3

            export UPSTREAM_PROJECT=upstream_job_name
            export UPSTREAM_BUILD=3
        ;;
        test3_checkout)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_job_name\n1" > ${OLD_REVISION_STATE_FILE}

            export JOB_NAME=job_name
            export BUILD_NUMBER=3
        ;;
        test4_checkout)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_job_name\n1" > ${OLD_REVISION_STATE_FILE}

            export JOB_NAME=job_name
            export BUILD_NUMBER=2
            export UPSTREAM_PROJECT=upstream_job_name
            export UPSTREAM_BUILD=1
        ;;
        test5_checkout)
            export CHANGELOG=$(createTempFile)
            export OLD_REVISION_STATE_FILE=$(createTempFile)
            echo -e "other_upstream_project_name\n1" > ${OLD_REVISION_STATE_FILE}

            export JOB_NAME=job_name
            export BUILD_NUMBER=2
            export UPSTREAM_PROJECT=upstream_job_name
            export UPSTREAM_BUILD=1
        ;;
        test7_compare)
            export REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_project_name\n1" > ${REVISION_STATE_FILE}
            export UPSTREAM_PROJECT=upstream_project_name
            export UPSTREAM_BUILD=4
        ;;
        test8_compare)
            export REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_project_name\n1" > ${REVISION_STATE_FILE}
            export UPSTREAM_PROJECT=upstream_project_name
            export UPSTREAM_BUILD=4
        ;;
        test9_compare)
            export REVISION_STATE_FILE=$(createTempFile)
            echo -e "other_upstream_project_name\n1" > ${REVISION_STATE_FILE}
            export UPSTREAM_PROJECT=upstream_project_name
            export UPSTREAM_BUILD=4
        ;;
        test10_compare)
            export REVISION_STATE_FILE=$(createTempFile)
            echo -e "upstream_project_name\n1" > ${REVISION_STATE_FILE}
            export UPSTREAM_PROJECT=upstream_project_name
            export UPSTREAM_BUILD=1
        ;;
        test11_calculate)
            export REVISION_STATE_FILE=$(createTempFile)
            export JOB_NAME=upstream_project_name
            export BUILD_NUMBER=2
            export UPSTREAM_PROJECT=upstream_project_name
            export UPSTREAM_BUILD=1
            export WORKSPACE=$(createTempDirectory)
        ;;
        test12_calculate)
            export REVISION_STATE_FILE=$(createTempFile)
            export JOB_NAME=upstream_project_name
            export BUILD_NUMBER=2
            export TESTED_BUILD_JOBNAME=upstream_project_name
            export TESTED_BUILD_NUMBER=1
            export WORKSPACE=$(createTempDirectory)
        ;;
        test13_calculate)
            export REVISION_STATE_FILE=$(createTempFile)
            export JOB_NAME=upstream_project_name
            export BUILD_NUMBER=2
            export WORKSPACE=$(createTempDirectory)
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
    echo 'jenkinsMasterServerHostName=localhost'                                        >  ${LFS_CI_CONFIG_FILE}
    echo 'jenkinsMasterServerPath = ${JEKINS_HOME}'                                     >> ${LFS_CI_CONFIG_FILE}
    echo 'CUSTOM_SCM_upstream_job_name = upstream_job_name'                             >> ${LFS_CI_CONFIG_FILE}
    echo "LFS_CI_global_mapping_branch_location < branchName:trunk > = pronb-developer" >> ${LFS_CI_CONFIG_FILE}


    return
}

test1_checkout() {
    assertTrue "first build of a branch / job => no old data available" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"
}
test2_checkout() {
    assertTrue "normal run, get changelog" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"

    assertExecutedCommands ${CHANGELOG} ${LFS_CI_ROOT}/test/data/10_customSCM.upstream_test2_expected_changelog.xml
}

test3_checkout() {
    assertTrue "build triggered by hand" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"

    assertExecutedCommands ${CHANGELOG} ${LFS_CI_ROOT}/test/data/10_customSCM.upstream_test2_expected_changelog.xml
}

test4_checkout() {
    assertTrue "rebuild without change in upstream" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"

    local expected=$(createTempFile)
    echo -n "<log/>" > ${expected}
    assertExecutedCommands ${CHANGELOG} ${expected}
}

test5_checkout() {
    assertFalse "something wrong: project name are different" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"
}

# test6() {
#     assertFalse "something wrong: project name are different" \
#         "${LFS_CI_ROOT}/bin/customSCM.upstream.sh checkout"
# }


test7_compare() {
    assertTrue "no revision state file" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh compare"

}

test8_compare() {
    assertTrue "regular upstream project change" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh compare"
}

test9_compare() {
    assertTrue "change in upstream project" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh compare"
}

test10_compare() {
    assertFalse "no change in upstream => no build" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh compare"
}

test10_compare() {
    assertFalse "no change in upstream => no build" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh compare"
}

test11_calculate() {
    assertTrue "upstream is set" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh calculate"
    local expect=$(createTempFile)
cat <<EOF > ${expect} 
upstream_project_name
1
EOF
    assertExecutedCommands ${expect} ${REVISION_STATE_FILE}
}

test12_calculate() {
    assertTrue "upstream is set" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh calculate"
    local expect=$(createTempFile)
cat <<EOF > ${expect} 
upstream_project_name
1
EOF
    assertExecutedCommands ${expect} ${REVISION_STATE_FILE}
}
test13_calculate() {
    assertTrue "upstream is set" \
        "${LFS_CI_ROOT}/bin/customSCM.upstream.sh calculate"
    local expect=$(createTempFile)
cat <<EOF > ${expect} 
upstream_job_name
3
EOF
    assertExecutedCommands ${expect} ${REVISION_STATE_FILE}
}
source lib/shunit2

exit 0

