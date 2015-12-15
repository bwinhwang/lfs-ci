#!/bin/bash

source test/common.sh
source lib/uc_cloud.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    createTempFile() {
        local cnt=$(cat ${UT_TMPDIR}/.cnt)
        cnt=$((cnt + 1 ))
        echo ${cnt} > ${UT_TMPDIR}/.cnt
        touch ${UT_TMPDIR}/tmp.${cnt}
        echo "y15-m12-d14-12:52:07 Finish ( euca-10-157-43-246.eucalyptus.escloc20.eecloud.nsn-net.net successfully started )" > ${UT_TMPDIR}/tmp.${cnt}
        echo ${UT_TMPDIR}/tmp.${cnt}
    }
    getConfig() {
        case $1 in
            *) echo $1 ;;
        esac
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription"
    }

    return
}

oneTimeTearDown() {
    return
}

setUp() {
    export LFS_CI_GLOBAL_PRODUCT_NAME=LFS
    export CREATE_CLOUD_INSTANCES_AMOUNT=1
    export CREATE_CLOUD_INSTANCES_TYPE=hs1.8xlarge
    export UT_TMPDIR=$(createTempDirectory)
    echo 0 > ${UT_TMPDIR}/.cnt

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${UT_TMPDIR}
    return
}

test_setup() {
    echo ""
}

test_ADMIN_CREATE_CLOUD_SLAVE_INSTANCE() {
    assertTrue "usecase_ADMIN_CREATE_CLOUD_SLAVE_INSTANCE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute source LFS_CI_CLOUD_USER_ROOT_DIR/LFS_CI_CLOUD_SLAVE_EUCARC
execute -l ${UT_TMPDIR}/tmp.1 LFS_CI_CLOUD_LFS2CLOUD -cLFS_CI_CLOUD_SLAVE_ESLOC -iLFS_CI_CLOUD_SLAVE_EMI -mLFS_CI_CLOUD_SLAVE_INSTANCETYPE -sLFS_CI -fLFS_CI_CLOUD_SLAVE_INSTALL_SCRIPT
setBuildDescription
EOF

    assertExecutedCommands ${expect}


    return
}

source lib/shunit2

exit 0
