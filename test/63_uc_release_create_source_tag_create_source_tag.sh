#!/bin/bash 
source test/common.sh
source lib/uc_release_create_source_tag.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in 
            LFS_CI_uc_release_can_create_source_tag)
                echo ${UT_CAN_SVN_ACTION}
            ;;
            *) echo $1 ;;
        esac
    }
    _mustHaveLfsSourceSubversionUrl() {
        mockedCommand "_mustHaveLfsSourceSubversionUrl $@"
        export svnUrl=http://svnMasterServerHostName/
        export svnUrlOs=http://svnMasterServerHostName/os
        export osLabelName=PS_LFS_OS_2015_09_0001
        export branchName=pre_${osLabelName}
        export commitMessageFile=${WORKSPACE}/commitMessage
    }
    svnCopy() {
        mockedCommand "svnCopy $@"
    }
    svnRemove() {
        mockedCommand "svnRemove $@"
    }

    return
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_CAN_SVN_ACTION=1
    assertTrue "_createSourceTag"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_mustHaveLfsSourceSubversionUrl 
getConfig LFS_CI_uc_release_can_create_source_tag
svnCopy -m ${WORKSPACE}/commitMessage http://svnMasterServerHostName//os/branches/pre_PS_LFS_OS_2015_09_0001 http://svnMasterServerHostName//os/tags/PS_LFS_OS_2015_09_0001
svnRemove -F ${WORKSPACE}/commitMessage http://svnMasterServerHostName/os/branches/pre_PS_LFS_OS_2015_09_0001
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_CAN_SVN_ACTION=
    assertTrue "_createSourceTag"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_mustHaveLfsSourceSubversionUrl 
getConfig LFS_CI_uc_release_can_create_source_tag
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
