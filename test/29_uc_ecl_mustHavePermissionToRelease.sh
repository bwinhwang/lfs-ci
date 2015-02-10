#!/bin/bash

source lib/common.sh

initTempDirectory

source lib/uc_ecl.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
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
    setBuildResultUnstable() {
        mockedCommand "setBuildResultUnstable $@"
    }
    runOnMaster() {
        mockedCommand "runOnMaster $@"
        echo ${UT_RUN_ON_MASTER}
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
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

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
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test3() {
    export BUILD_NUMBER=1
    export UT_CONFIG_EVERY_X_RELEASE=4
    export UT_CONFIG_MAX_TIME=10000
    export UT_RUN_ON_MASTER=123000
    export UT_DATE_SECONDS=150
    export UT_LAST_BUILD_DIRECTORY=/path/to/last/build

    # last build: 123 (123000 in ms)
    # now:        150
    # MAX TIME:    10 (10000 in ms)

    assertTrue "mustHavePermissionToRelease"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig LFS_CI_uc_update_ecl_update_promote_every_xth_release
getBuildDirectoryOnMaster lastSuccessfulBuild
runOnMaster ${LFS_CI_ROOT}/bin/xpath -q -e /build/startTime/node() ${UT_LAST_BUILD_DIRECTORY}/build.xml
date +%s
getConfig LFS_CI_uc_ecl_maximum_time_between_two_releases
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test4() {
    export BUILD_NUMBER=1
    export UT_CONFIG_EVERY_X_RELEASE=4
    export UT_CONFIG_MAX_TIME=10000
    export UT_RUN_ON_MASTER=123000
    export UT_DATE_SECONDS=124
    export UT_LAST_BUILD_DIRECTORY=/path/to/last/build

    # last build: 123 ( 123000 in ms)
    # now:        124
    # MAX TIME:    10 (10000 in ms)
    # => should be unstable

    assertTrue "mustHavePermissionToRelease"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig LFS_CI_uc_update_ecl_update_promote_every_xth_release
getBuildDirectoryOnMaster lastSuccessfulBuild
runOnMaster /home/bm/projekte/work/nsn/ci.git/bin/xpath -q -e /build/startTime/node() /path/to/last/build/build.xml
date +%s
getConfig LFS_CI_uc_ecl_maximum_time_between_two_releases
setBuildDescription 1 <br>not promoted
setBuildResultUnstable 
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

source lib/shunit2

exit 0

