#!/bin/bash

source test/common.sh

source lib/uc_developer_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }

    specialBuildPreparation() {
        mockedCommand "specialBuildPreparation $@"
    }
    date() {
        echo date
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export DEVBUILD_REVISION=12345
    export DEVBUILD_LOCATION=trunk
    export REQUESTOR_USERID=userName

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_DEVELOPER_BUILD"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
specialBuildPreparation DEV DEV_USERNAME_TRUNK_12345.date 12345 trunk
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export DEVBUILD_LOCATION=
    assertFalse "usecase_LFS_DEVELOPER_BUILD"
    return
}

test3() {
    export REQUESTOR_USERID=
    assertFalse "usecase_LFS_DEVELOPER_BUILD"
    return
}

test4() {
    export DEVBUILD_REVISION=
    assertFalse "usecase_LFS_DEVELOPER_BUILD"
    return
}

source lib/shunit2

exit 0
