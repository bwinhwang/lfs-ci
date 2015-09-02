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
    assertTrue "_createUsedRevisionsFile"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd
    echo "src-bos http://svne1/os/src-bos 12345" > ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/usedRevisions.txt

    # assertTrue "_createUsedRevisionsFile"
    _createUsedRevisionsFile

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
