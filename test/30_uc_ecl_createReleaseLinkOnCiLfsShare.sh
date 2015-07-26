#!/bin/bash

source test/common.sh
source lib/uc_ready_for_release.sh

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
                echo ${UT_LINK_DIRECTORY}/RCversion/os
            ;;
            LFS_CI_UC_package_copy_to_share_path_name)
                echo Release_Candidate/FSM-r3
            ;;
        esac
    }
    getNextCiLabelName() {
        mockedCommand "getNextCiLabelName $@"
        echo "PS_LFS_OS_2015_07_0000"
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
    export UT_LINK_DIRECTORY=$(createTempDirectory)
    mkdir -p ${UT_LINK_DIRECTORY}/RCversion/os
    return
}
tearDown() {
    true 
}

test1() {
    assertTrue "createReleaseLinkOnCiLfsShare"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getNextCiLabelName 
getConfig LFS_CI_UC_package_copy_to_share_link_location
getConfig LFS_CI_UC_package_copy_to_share_path_name
execute mkdir -p ${UT_LINK_DIRECTORY}/RCversion/os
execute cd ${UT_LINK_DIRECTORY}/RCversion/os
execute ln -sf ../../Release_Candidate/FSM-r3/PS_LFS_OS_2015_07_0000 PS_LFS_REL_2015_07_0000
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    ln -fs /dev/null ${UT_LINK_DIRECTORY}/RCversion/os/PS_LFS_REL_2015_07_0000
    assertFalse "createReleaseLinkOnCiLfsShare PS_LFS_OS_2015_07_0000"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getNextCiLabelName 
getConfig LFS_CI_UC_package_copy_to_share_link_location
getConfig LFS_CI_UC_package_copy_to_share_path_name
execute mkdir -p ${UT_LINK_DIRECTORY}/RCversion/os
execute cd ${UT_LINK_DIRECTORY}/RCversion/os
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0

