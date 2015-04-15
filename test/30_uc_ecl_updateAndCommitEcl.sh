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
    svnCommit() {
        mockedCommand "svnCommit $@"
    }
    svnDiff() {
        mockedCommand "svnDiff $@"
    }
    svnCheckout() {
        mockedCommand "svnCheckout $@"
        mkdir -p $2
        touch $2/ECL
    }
    getEclValue() {
        mockedCommand "getEclValue $@"
        echo value_$1
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_uc_update_ecl_can_commit_ecl)
                echo ${UT_CAN_COMMIT}
            ;;
            LFS_CI_uc_update_ecl_key_names)
                echo ECL_KEY1 ECL_KEY2
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
    export UT_CAN_COMMIT=1
    assertTrue "updateAndCommitEcl http://svn/ecl/url"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute rm -rfv ${WORKSPACE}/workspace/ecl_checkout
svnCheckout http://svn/ecl/url ${WORKSPACE}/workspace/ecl_checkout
getConfig LFS_CI_uc_update_ecl_key_names
getEclValue ECL_KEY1 
execute perl -pi -e s:^ECL_KEY1=.*:ECL_KEY1=value_ECL_KEY1: ${WORKSPACE}/workspace/ecl_checkout/ECL
getEclValue ECL_KEY2 
execute perl -pi -e s:^ECL_KEY2=.*:ECL_KEY2=value_ECL_KEY2: ${WORKSPACE}/workspace/ecl_checkout/ECL
svnDiff ${WORKSPACE}/workspace/ecl_checkout/ECL
getConfig LFS_CI_uc_update_ecl_can_commit_ecl
svnCommit -F ${WORKSPACE}/workspace/ecl_commit_message ${WORKSPACE}/workspace/ecl_checkout/ECL
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_CAN_COMMIT=
    assertTrue "updateAndCommitEcl http://svn/ecl/url"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute rm -rfv ${WORKSPACE}/workspace/ecl_checkout
svnCheckout http://svn/ecl/url ${WORKSPACE}/workspace/ecl_checkout
getConfig LFS_CI_uc_update_ecl_key_names
getEclValue ECL_KEY1 
execute perl -pi -e s:^ECL_KEY1=.*:ECL_KEY1=value_ECL_KEY1: ${WORKSPACE}/workspace/ecl_checkout/ECL
getEclValue ECL_KEY2 
execute perl -pi -e s:^ECL_KEY2=.*:ECL_KEY2=value_ECL_KEY2: ${WORKSPACE}/workspace/ecl_checkout/ECL
svnDiff ${WORKSPACE}/workspace/ecl_checkout/ECL
getConfig LFS_CI_uc_update_ecl_can_commit_ecl
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0

