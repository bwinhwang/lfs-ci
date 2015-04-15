#!/bin/bash

source test/common.sh
source lib/uc_ecl.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_UC_package_copy_to_share_link_location) 
                echo /build/home/CI_LFS/Release/
            ;;
            LFS_CI_UC_package_copy_to_share_path_name)
                echo Release_Candidate/FSM-r3
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
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Build
    export UPSTREAM_BUILD=1234
    return
}
tearDown() {
    true 
}

test1() {
    assertTrue "createReleaseLinkOnCiLfsShare PS_LFS_OS_2015_01_0000"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig LFS_CI_UC_package_copy_to_share_link_location
getConfig LFS_CI_UC_package_copy_to_share_path_name
execute mkdir -p /build/home/CI_LFS/Release/
execute cd /build/home/CI_LFS/Release/
execute ln -sf ../../Release_Candidate/FSM-r3/PS_LFS_OS_2015_01_0000 PS_LFS_REL_2015_01_0000
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

