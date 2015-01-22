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

testConfigRegexMatch1() {
    local cfg=$(createTempFile)
    echo "foo            = barbarbar" > ${cfg}
    echo "bar            = 2"        >> ${cfg}
    echo "bar < foo~bar> = 3"        >> ${cfg}

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg}"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg})
    assertEquals "value from getConfig" "3" "${value}"
}

testConfigRegexMatch2() {
    local cfg=$(createTempFile)
    export FOOBAR=maxi.emea.nsn-net.net

    echo "bar                = 2"  > ${cfg}
    echo "bar < FOOBAR~emea> = 3" >> ${cfg}

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg}"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg})
    assertEquals "value from getConfig" "3" "${value}"
}

testConfigRegexMatch3() {
    local cfg=$(createTempFile)
    export FOOBAR=maxi.emea.nsn-net.net

    echo "bar                = 2"  > ${cfg}
    echo "bar < FOOBAR~maxi> = 3" >> ${cfg}

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg}"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg})
    assertEquals "value from getConfig" "3" "${value}"
}

testConfigRegexMatch4() {
    local cfg=$(createTempFile)
    export FOOBAR=maxi.emea.nsn-net.net

    echo "bar                 = 2"  > ${cfg}
    echo "bar < FOOBAR~^maxi> = 3" >> ${cfg}

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg}"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg})
    assertEquals "value from getConfig" "3" "${value}"
}

testConfigRegexMatch5() {
    local cfg=$(createTempFile)
    export FOOBAR=maxi.emea.nsn-net.net

    echo "bar                = 2"  > ${cfg}
    echo "bar < FOOBAR~net$> = 3" >> ${cfg}

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg}"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg})
    assertEquals "value from getConfig" "3" "${value}"
}

testConfigOrderCheck() {
    local cfg=$(createTempFile)

    echo "bar = 2"  > ${cfg}
    echo "bar = 3" >> ${cfg}

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg}"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg})
    assertEquals "value from getConfig" "2" "${value}"
}

source lib/shunit2

exit 0

