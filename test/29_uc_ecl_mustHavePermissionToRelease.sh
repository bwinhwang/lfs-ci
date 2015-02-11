#!/bin/bash

source test/common.sh

source lib/uc_ecl.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        echo ${UT_RUN_ON_MASTER}
    }
    mustExistFile() {
        mockedCommand "mustExistFile $@"
    }
    getBuildDirectoryOnMaster() {
        mockedCommand "getBuildDirectoryOnMaster $@"
        echo ${UT_LAST_BUILD_DIRECTORY}
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    copyFileFromBuildDirectoryToWorkspace() {
        mockedCommand "copyFileFromBuildDirectoryToWorkspace $@"
    }
    setBuildResultUnstable() {
        mockedCommand "setBuildResultUnstable $@"
    }
    date() {
        if [[ "$1" == "+%s" ]] ; then
            echo ${UT_DATE_SECONDS}
            mockedCommand "date $@"
        fi
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_uc_update_ecl_update_promote_every_xth_release)
                echo ${UT_CONFIG_EVERY_X_RELEASE}
            ;;
            LFS_CI_uc_ecl_maximum_time_between_two_releases)
                echo ${UT_CONFIG_MAX_TIME}
            ;;
        esac
    }
}
oneTimeTearDown() {
    true
}
setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
    touch  ${UT_MOCKED_COMMANDS}
}
tearDown() {
    true 
}

test1() {
    export BUILD_NUMBER=0
    export UT_CONFIG_EVERY_X_RELEASE=1
    export UT_CONFIG_MAX_TIME=0

    assertTrue "mustHavePermissionToRelease"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig LFS_CI_uc_update_ecl_update_promote_every_xth_release
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export BUILD_NUMBER=1
    export UT_CONFIG_EVERY_X_RELEASE=1
    export UT_CONFIG_MAX_TIME=0

    assertTrue "mustHavePermissionToRelease"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig LFS_CI_uc_update_ecl_update_promote_every_xth_release
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build
    export BUILD_NUMBER=1
    export UT_CONFIG_EVERY_X_RELEASE=4
    export UT_CONFIG_MAX_TIME=10000
    export UT_RUN_ON_MASTER=123000
    export UT_DATE_SECONDS=150
    export UT_LAST_BUILD_DIRECTORY=/path/to/last/build
    export WORKSPACE=$(createTempDirectory)

    # last build: 123 (123000 in ms)
    # now:        150
    # MAX TIME:    10 (10000 in ms)

    mustHavePermissionToRelease
    # assertTrue "mustHavePermissionToRelease"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig LFS_CI_uc_update_ecl_update_promote_every_xth_release
copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} lastSuccessfulBuild ${WORKSPACE}/build.xml
execute -n /home/bm/projekte/work/nsn/ci.git/bin/xpath -q -e /build/startTime/node() ${WORKSPACE}/build.xml
date +%s
getConfig LFS_CI_uc_ecl_maximum_time_between_two_releases
EOF
    assertExecutedCommands ${expect}

    return
}

test4() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build
    export BUILD_NUMBER=1
    export UT_CONFIG_EVERY_X_RELEASE=4
    export UT_CONFIG_MAX_TIME=10000
    export UT_RUN_ON_MASTER=123000
    export UT_DATE_SECONDS=124
    export UT_LAST_BUILD_DIRECTORY=/path/to/last/build
    export WORKSPACE=$(createTempDirectory)

    # last build: 123 ( 123000 in ms)
    # now:        124
    # MAX TIME:    10 (10000 in ms)
    # => should be unstable

    assertTrue "mustHavePermissionToRelease"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig LFS_CI_uc_update_ecl_update_promote_every_xth_release
copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} lastSuccessfulBuild ${WORKSPACE}/build.xml
execute -n ${LFS_CI_ROOT}/bin/xpath -q -e /build/startTime/node() ${WORKSPACE}/build.xml
date +%s
getConfig LFS_CI_uc_ecl_maximum_time_between_two_releases
setBuildDescription LFS_CI_-_trunk_-_Build 1 <br>not promoted
setBuildResultUnstable 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

