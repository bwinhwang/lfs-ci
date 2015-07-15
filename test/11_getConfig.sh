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

    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/global.cfg

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

testConfigInclude() {
    local cfg1=$(createTempFile)
    local cfg2=$(createTempFile)

    echo "bar = 1"  > ${cfg1}
    echo "bar = 2" >> ${cfg1}
    echo "include ${cfg2}" >> ${cfg1}
    echo "foo = 3"  > ${cfg2}
    echo "foo = 4" >> ${cfg2}

    assertTrue "${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg1}"
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k bar -f ${cfg1})
    assertEquals "value from getConfig" "1" "${value}"

    local value=$(${LFS_CI_ROOT}/bin/getConfig -k foo -f ${cfg1})
    assertEquals "value from getConfig" "3" "${value}"
}

testConfigInclude2() {
    local cfg1=$(createTempFile)
    local cfg2=$(createTempFile)

    echo "foo = 1"          > ${cfg1}
    echo "foo = 2"         >> ${cfg1}
    echo "include ${cfg2}" >> ${cfg1}
    echo "foo = 3"          > ${cfg2}
    echo "foo = 4"         >> ${cfg2}

    local value=$(${LFS_CI_ROOT}/bin/getConfig -k foo -f ${cfg1})
    assertEquals "value from getConfig" "1" "${value}"
}

testConfigInclude3() {
    local cfg1=$(createTempFile)
    local cfg2=$(createTempFile)

    echo "include ${cfg2}" >> ${cfg1}
    echo "foo = 1"         >> ${cfg1}
    echo "foo = 2"         >> ${cfg1}
    echo "foo = 3"         >> ${cfg2}
    echo "foo = 4"         >> ${cfg2}

    local value=$(${LFS_CI_ROOT}/bin/getConfig -k foo -f ${cfg1})
    assertEquals "value from getConfig" "3" "${value}"
}

testConfigInclude4() {
    local dir=$(createTempDirectory)
    local cfg1=${dir}/cfg1
    local cfg2=${dir}/cfg2

    echo "include cfg2" >> ${cfg1}
    echo "foo = 1"      >> ${cfg1}
    echo "foo = 2"      >> ${cfg1}
    echo "foo = 3"      >> ${cfg2}
    echo "foo = 4"      >> ${cfg2}

    local value=$(${LFS_CI_ROOT}/bin/getConfig -k foo -f ${cfg1})
    assertEquals "value from getConfig" "3" "${value}"
}

testConfigInclude5() {
    local dir=$(createTempDirectory)
    local cfg1=${dir}/cfg1
    local cfg2=${dir}/cfg2

    echo "include cfg2" >> ${cfg1}
    echo "foo = 1"      >> ${cfg1}
    echo "foo = 2"      >> ${cfg1}
    echo "foo = 3"      >> ${cfg2}
    echo "foo = 4"      >> ${cfg2}

    cd ${dir}
    local value=$(${LFS_CI_ROOT}/bin/getConfig -k foo -f cfg1)
    assertEquals "value from getConfig" "3" "${value}"
    cd - >/dev/null
}

testConfigDifferentConfigFile() {
    local cfg1=$(createTempFile)
    local cfg2=$(createTempFile)

    echo "foo = 1"          > ${cfg1}
    echo "bar = 2"         >> ${cfg1}
    export LFS_CI_CONFIG_FILE=${cfg1}

    echo "foo = 3"          > ${cfg2}
    echo "bar = 4"         >> ${cfg2}

    local value=$(${LFS_CI_ROOT}/bin/getConfig -k foo -f ${cfg2})
    assertEquals "value from getConfig" "3" "${value}"
}
source lib/shunit2

exit 0

