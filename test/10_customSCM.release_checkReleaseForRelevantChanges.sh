#!/bin/bash

source test/common.sh
source lib/customSCM.release.sh

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
    export UT_CAN_CHECK=1
    export UT_FILTER=${LFS_CI_ROOT}/etc/customSCM.release.filter.relevantChanges.txt

    export CHANGELOG=${LFS_CI_ROOT}/test/data/10_customSCM.release_checkReleaseForRelevantChanges_changelog1.xml

    case ${_shunit_test_} in
        test1_canCheck)
            export UT_CAN_CHECK= 
        ;;
        test2_noFilter)
            export UT_FILTER= 
        ;;
        test3_noRelevantChange)
            export CHANGELOG=${LFS_CI_ROOT}/test/data/10_customSCM.release_checkReleaseForRelevantChanges_changelog2.xml
        ;;
    esac

    export LFS_CI_CONFIG_FILE=$(createTempFile)
    echo "CUSTOM_SCM_release_check_for_relevant_changes = ${UT_CAN_CHECK}" >  ${LFS_CI_CONFIG_FILE}
    echo "CUSTOM_SCM_release_check_for_relevant_change_filter_file = ${UT_FILTER}" >> ${LFS_CI_CONFIG_FILE}

    return
}

test1_canCheck() {
    assertFalse "has no permission to check" "_checkReleaseForRelevantChanges ${CHANGELOG}"
}
test2_noFilter() {
    assertFalse "has no filter" "_checkReleaseForRelevantChanges ${CHANGELOG}"
}
test3_noRelevantChange() {
    assertFalse "has no relevant change" "_checkReleaseForRelevantChanges ${CHANGELOG}"
}
test4_relevantChange() {
    assertTrue "has relevant changes" "_checkReleaseForRelevantChanges ${CHANGELOG}"
}

source lib/shunit2

exit 0

