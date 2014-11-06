#!/bin/bash

source lib/common.sh

initTempDirectory


oneTimeSetUp() {
    true        
}
oneTimeTearDown() {
    true
}

testConfigFileTest() {
    local cfg=$(createTempFile)
    echo "foo = 1"  > ${cfg}
    echo "bar = 2" >> ${cfg}

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k foo -f ${cfg}"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k foo -f ${cfg})
    assertEquals "value from getConfig" "1" "${value}"
}

testDefaultConfigFile() {

    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/file.cfg

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k foo"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k foo)
    assertEquals "value from getConfig" "" "${value}"
}

source lib/shunit2

exit 0

