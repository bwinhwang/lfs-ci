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
    return
}
setUp() {
    export UT_CAN_CHECK=1
    export CHANGELOG=${LFS_CI_ROOT}/test/data/10_customSCM.release_checkReleaseForRelevantChanges_changelog1.xml

    case ${_shunit_test_} in
        test1_canCheck)
            export UT_CAN_CHECK= 
        ;;
        test2_noRelevantChange)
            export CHANGELOG=$(createTempFile)
            echo '<logs />' >> ${CHANGELOG}
        ;;
    esac

    export LFS_CI_CONFIG_FILE=$(createTempFile)
    echo "CUSTOM_SCM_release_check_for_empty_changelog = ${UT_CAN_CHECK}" >  ${LFS_CI_CONFIG_FILE}

    return
}

test1_canCheck() {
    assertFalse "has no permission to check" "_checkReleaseForEmptyChangelog ${CHANGELOG}"
}
test2_noRelevantChange() {
    assertTrue "has no relevant change" "_checkReleaseForEmptyChangelog ${CHANGELOG}"
}
test3_relevantChange() {
    assertFalse "has relevant changes" "_checkReleaseForEmptyChangelog ${CHANGELOG}"
}

source lib/shunit2

exit 0

