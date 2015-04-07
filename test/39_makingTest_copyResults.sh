#!/bin/bash

source test/common.sh

source lib/makingtest.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    _reserveTarget(){
        mockedCommand "_reserveTarget $@"
        echo "TargetName"
    }
    mustHaveMakingTestTestConfig(){
        mockedCommand "mustHaveMakingTestTestConfig $@"
    }
    makingTest_testSuiteDirectory() {
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo ${WORKSPACE}/workspace/path/to/test/suite
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "makingTest_copyResults"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveMakingTestTestConfig 
makingTest_testSuiteDirectory 
mustExistDirectory ${WORKSPACE}/workspace/path/to/test/suite
execute mkdir -p ${WORKSPACE}/workspace/xml-reports/ ${WORKSPACE}/workspace/bld/bld-test-xml/results ${WORKSPACE}/workspace/bld/bld-test-artifacts/results
execute cp -fr ${WORKSPACE}/workspace/path/to/test/suite/xml-reports/*.xml ${WORKSPACE}/workspace/bld/bld-test-xml/results/
execute cp -f ${WORKSPACE}/workspace/path/to/test/suite/xml-reports/*.xml ${WORKSPACE}/workspace/xml-reports/
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    # with __artifacts
    mkdir -p ${WORKSPACE}/workspace/path/to/test/suite/__artifacts

    assertTrue "makingTest_copyResults"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveMakingTestTestConfig 
makingTest_testSuiteDirectory 
mustExistDirectory ${WORKSPACE}/workspace/path/to/test/suite
execute mkdir -p ${WORKSPACE}/workspace/xml-reports/ ${WORKSPACE}/workspace/bld/bld-test-xml/results ${WORKSPACE}/workspace/bld/bld-test-artifacts/results
execute cp -fr ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/* ${WORKSPACE}/workspace/bld/bld-test-artifacts/results/
execute cp -fr ${WORKSPACE}/workspace/path/to/test/suite/xml-reports/*.xml ${WORKSPACE}/workspace/bld/bld-test-xml/results/
execute cp -f ${WORKSPACE}/workspace/path/to/test/suite/xml-reports/*.xml ${WORKSPACE}/workspace/xml-reports/
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
