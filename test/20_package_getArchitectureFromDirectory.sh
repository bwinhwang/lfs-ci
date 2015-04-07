#!/bin/bash

source lib/common.sh

initTempDirectory

source lib/package.sh

oneTimeSetUp() {
    export JOB_NAME=LFS_CI_-_trunk_-_Package_-_package
}
oneTimeTearDown() {
    true
}

testGetArchitectureFromDirectory() {
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-fsm3_octeon2)" \
                 "mips64-octeon2-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-fct)" \
                 "mips64-octeon2-linux-gnu"
#    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-lrc-octeon2)" \
#                 "mips64-octeon2-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-lcpa)" \
                 "mips64-octeon2-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-qemu)" \
                 "i686-pc-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-qemu_i386)" \
                 "i686-pc-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-qemu_64)" \
                 "x86_64-pc-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-qemu_x86_64)" \
                 "x86_64-pc-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-fcmd)" \
                 "powerpc-e500-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-fspc)" \
                 "powerpc-e500-linux-gnu"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-axm)" \
                 "arm-cortexa15-linux-gnueabihf"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-keystone2)" \
                 "arm-cortexa15-linux-gnueabihf"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-fsm4_k2)" \
                 "arm-cortexa15-linux-gnueabihf"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-fsm4_arm)" \
                 "arm-cortexa15-linux-gnueabihf"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-fsm4_axm)" \
                 "arm-cortexa15-linux-gnueabihf"
    assertEquals "$(getArchitectureFromDirectory $workspace/bld-foo-arm)" \
                 "arm-cortexa15-linux-gnueabihf"
    return
}
testGetPlatformFromDirectory() {
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-fsm3_octeon2)" \
                 "fsm3_octeon2"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-fct)" \
                 "fsm3_octeon2"
#    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-lrc-octeon2)" \
#                 "mips64-octeon2-linux-gnu"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-lcpa)" \
                 "lrc-octeon2"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-qemu)" \
                 "qemu"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-qemu_64)" \
                 "qemu_64"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-qemu_i386)" \
                 "qemu"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-qemu_x86_64)" \
                 "qemu_64"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-fcmd)" \
                 "fcmd"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-fspc)" \
                 "fspc"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-axm)" \
                 "fsm4_axm"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-keystone2)" \
                 "fsm4_k2"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-fsm4_k2)" \
                 "fsm4_k2"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-fsm4_arm)" \
                 "fsm4_k2"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-fsm4_axm)" \
                 "fsm4_axm"
    assertEquals "$(getPlatformFromDirectory $workspace/bld-foo-arm)" \
                 "fsm4_k2"
    return
}

source lib/shunit2

exit 0

