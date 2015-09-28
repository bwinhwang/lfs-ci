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
    }
    mustExistBranchInSubversion() {
        mockedCommand "mustExistBranchInSubversion $@"
    }
    existsInSubversion() {
        mockedCommand "existsInSubversion $@"
        return ${UT_EXISTS_IN_SVN}
    }
    svnCopy() {
        mockedCommand "svnCopy $@"
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
    export UT_EXISTS_IN_SVN=1
    export UT_CAN_SVN_ACTION=1
    assertTrue "_copySourceDirectoryToBranch fsmr2 src-bos http://svne1/os/trunk/src-bos 12345"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_release_can_create_source_tag
getConfig svnMasterServerHostName
getConfig LFS_PROD_uc_release_source_tag_prefix -t target:fsmr2
_mustHaveLfsSourceSubversionUrl 
svnCopy -r 12345 -F http://svnMasterServerHostName/os/trunk/src-bos http://svnMasterServerHostName/os/branches/pre_PS_LFS_OS_2015_09_0001/fsmr2/src-bos
existsInSubversion http://svnMasterServerHostName//subsystems/src-bos/ LFS_PROD_uc_release_source_tag_prefixPS_LFS_OS_2015_09_0001
svnCopy -m http://svnMasterServerHostName/os/branches/pre_PS_LFS_OS_2015_09_0001/fsmr2/src-bos http://svnMasterServerHostName//subsystems/src-bos/LFS_PROD_uc_release_source_tag_prefixPS_LFS_OS_2015_09_0001
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_EXISTS_IN_SVN=0
    export UT_CAN_SVN_ACTION=1
    assertTrue "_copySourceDirectoryToBranch fsmr2 src-bos http://svne1/os/trunk/src-bos 12345"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_release_can_create_source_tag
getConfig svnMasterServerHostName
getConfig LFS_PROD_uc_release_source_tag_prefix -t target:fsmr2
_mustHaveLfsSourceSubversionUrl 
svnCopy -r 12345 -F http://svnMasterServerHostName/os/trunk/src-bos http://svnMasterServerHostName/os/branches/pre_PS_LFS_OS_2015_09_0001/fsmr2/src-bos
existsInSubversion http://svnMasterServerHostName//subsystems/src-bos/ LFS_PROD_uc_release_source_tag_prefixPS_LFS_OS_2015_09_0001
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    export UT_EXISTS_IN_SVN=0
    export UT_CAN_SVN_ACTION=
    assertTrue "_copySourceDirectoryToBranch fsmr2 src-bos http://svne1/os/trunk/src-bos 12345"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_release_can_create_source_tag
getConfig svnMasterServerHostName
getConfig LFS_PROD_uc_release_source_tag_prefix -t target:fsmr2
_mustHaveLfsSourceSubversionUrl 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
