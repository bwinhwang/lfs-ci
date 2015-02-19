#!/bin/bash

source lib/common.sh

initTempDirectory

source lib/build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }

}
oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
}
tearDown() {
    true 
}

testCheckoutSubprojectDirectories_test1() {
    export WORKSPACE=$(createTempDirectory)
    assertTrue "checkoutSubprojectDirectories src-project 123456"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute build adddir src-project --revision=123456
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

testCheckoutSubprojectDirectories_test2() {
    export WORKSPACE=$(createTempDirectory)
    assertTrue "checkoutSubprojectDirectories src-project"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute build adddir src-project
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

testCheckoutSubprojectDirectories_test3() {
    export WORKSPACE=$(createTempDirectory)
    assertTrue "checkoutSubprojectDirectories src-project LABEL"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute build adddir src-project LABEL
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}
source lib/shunit2

exit 0

