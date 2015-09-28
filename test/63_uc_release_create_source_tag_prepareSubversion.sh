#!/bin/bash 
source test/common.sh
source lib/uc_release_create_source_tag.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    _mustHaveLfsSourceSubversionUrl() {
        mockedCommand "_mustHaveLfsSourceSubversionUrl $@"
        export svnUrl=http://svnMasterServerHostName/
        export svnUrlOs=http://svnMasterServerHostName/os
        export osLabelName=PS_LFS_OS_2015_09_0001
        export branchName=pre_${osLabelName}
        export commitMessageFile=${WORKSPACE}/commitMessage
    }
    existsInSubversion() {
        mockedCommand "existsInSubversion $@"
        if [[ $@ =~ branches ]] ; then
            return ${UT_EXISTS_IN_SVN_2}
        else
            return ${UT_EXISTS_IN_SVN}
        fi
    }
    svnRemove() {
        mockedCommand "svnRemove $@"
    }
    mustExistBranchInSubversion() {
        mockedCommand "mustExistBranchInSubversion $@"
    }

    return
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_EXISTS_IN_SVN=1
    export UT_EXISTS_IN_SVN_2=1
    assertTrue "_prepareSubversion"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_mustHaveLfsSourceSubversionUrl 
existsInSubversion http://svnMasterServerHostName/os/tags PS_LFS_OS_2015_09_0001
existsInSubversion http://svnMasterServerHostName/os/branches pre_PS_LFS_OS_2015_09_0001
mustExistBranchInSubversion http://svnMasterServerHostName/os/branches pre_PS_LFS_OS_2015_09_0001
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_EXISTS_IN_SVN=0
    export UT_EXISTS_IN_SVN_2=1
    assertFalse "_prepareSubversion"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_mustHaveLfsSourceSubversionUrl 
existsInSubversion http://svnMasterServerHostName/os/tags PS_LFS_OS_2015_09_0001
EOF
    assertExecutedCommands ${expect}

    return
}
test3() {
    export UT_EXISTS_IN_SVN=1
    export UT_EXISTS_IN_SVN_2=0
    assertTrue "_prepareSubversion"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_mustHaveLfsSourceSubversionUrl 
existsInSubversion http://svnMasterServerHostName/os/tags PS_LFS_OS_2015_09_0001
existsInSubversion http://svnMasterServerHostName/os/branches pre_PS_LFS_OS_2015_09_0001
svnRemove -F ${WORKSPACE}/commitMessage http://svnMasterServerHostName/os/branches/pre_PS_LFS_OS_2015_09_0001
mustExistBranchInSubversion http://svnMasterServerHostName/os/branches pre_PS_LFS_OS_2015_09_0001
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
