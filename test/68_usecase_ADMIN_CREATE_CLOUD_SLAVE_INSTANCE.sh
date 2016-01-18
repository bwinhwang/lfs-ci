#!/bin/bash
# Author: Reiner Biefel

source test/common.sh
source lib/uc_cloud.sh

oneTimeSetUp() {
    # create a temp file.cfg
    export UT_CFG_FILE=$(createTempFile)
    export UT_JENKINS_CLI_JAR=/tmp/UT_JENKINS_CLI_JAR
    touch ${UT_JENKINS_CLI_JAR}
    echo "jenkinsRoot = /var/fpwork/xxx/lfs-jenkins"                                                              > ${UT_CFG_FILE}
    #echo "LFS_CI_CLOUD_LFS2CLOUD = /admulm/cloud/tools/lfs2cloud"                                                >> ${UT_CFG_FILE}
    echo "LFS_CI_CLOUD_LFS2CLOUD = echo LFS2CLOUD"                                                               >> ${UT_CFG_FILE}
    echo "LFS_CI_CLOUD_USER_ROOT_DIR = /home/${USER}/tools/eecloud"                                              >> ${UT_CFG_FILE}
    echo "LFS_CI_CLOUD_SLAVE_ESLOC = escloc20"                                                                   >> ${UT_CFG_FILE}
    echo "LFS_CI_CLOUD_SLAVE_INST_START_PARAMS = -z escloc20_1"                                                  >> ${UT_CFG_FILE}
    echo "LFS_CI_CLOUD_SLAVE_EUCARC = ec2_access_keys_etc/ec2keys_escloc20_user_psulm_OHN_Prod_Cloud/eucarc"     >> ${UT_CFG_FILE}
    echo "LFS_CI_CLOUD_SLAVE_EMI = emi-1d6a6f19"                                                                 >> ${UT_CFG_FILE}
    echo "LFS_CI_CLOUD_SLAVE_INSTALL_SCRIPT = ${LFS_CI_ROOT}/etc/cloud_ci-slaves_install_additional_packages.sh" >> ${UT_CFG_FILE}
    echo "JENKINS_CLI_JAR = ${UT_JENKINS_CLI_JAR}"                                                               >> ${UT_CFG_FILE}
    export LFS_CI_CONFIG_FILE=${UT_CFG_FILE}

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
        echo "y15-m12-d15-11:08:59 Awaiting Instance 1 [i-c378248e] in running mode...                                      OK" > ${UT_TMPDIR}/tmp.${cnt}
        echo "y15-m12-d14-12:52:07 Finish ( euca-10-157-43-246.eucalyptus.escloc20.eecloud.nsn-net.net successfully started )" >> ${UT_TMPDIR}/tmp.${cnt}
        echo ${UT_TMPDIR}/tmp.${cnt}
    }
    getConfig() {
        case $1 in
            *) echo $1 ;;
        esac
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }

    return
}

oneTimeTearDown() {
    return
}

setUp() {
    export LFS_CI_GLOBAL_PRODUCT_NAME=LFS
    export JOB_NAME=Admin_-_createCloudSlaveInstance
    export BUILD_NUMBER=1234
    export CREATE_CLOUD_INSTANCES_AMOUNT=1
    export CREATE_CLOUD_INSTANCES_TYPE=hs1.8xlarge
    export CREATE_CLOUD_INSTANCES_NEW_CI_SLAVE=true
    export allcloudDnsName="euca-10-157-43-246.eucalyptus.escloc20.eecloud.nsn-net.net [i-c378248e]"
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
    cat ${LFS_CI_CONFIG_FILE}
    echo ""
}

test_ADMIN_CREATE_CLOUD_SLAVE_INSTANCE() {
    assertTrue "usecase_ADMIN_CREATE_CLOUD_SLAVE_INSTANCE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -l ${UT_TMPDIR}/tmp.2 LFS_CI_CLOUD_LFS2CLOUD -cLFS_CI_CLOUD_SLAVE_ESLOC -iLFS_CI_CLOUD_SLAVE_EMI -m${CREATE_CLOUD_INSTANCES_TYPE} -sLFS_CI -fLFS_CI_CLOUD_SLAVE_INSTALL_SCRIPT
setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${allcloudDnsName}
EOF

    assertExecutedCommands ${expect}


    return
}

source lib/shunit2

exit 0
