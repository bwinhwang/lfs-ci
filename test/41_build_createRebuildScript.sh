#!/bin/bash

source test/common.sh
source lib/build.sh

oneTimeSetUp() {
    true
}
oneTimeTearDown() {
    true
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export BUILD_NUMBER=1

    local ws=${WORKSPACE}/workspace/bld
    mkdir -p ${ws}/bld-externalComponents-summary
    mkdir -p ${ws}/bld-externalComponents-fcmd

    echo "sdk3 <> = SDK3_123"        >> ${ws}/bld-externalComponents-summary/externalComponents
    echo "pkgpool <> = PKGPOOL_1234" >> ${ws}/bld-externalComponents-summary/externalComponents

    echo "src-foo http://fake/url/foo 1234" >> ${ws}/bld-externalComponents-fcmd/usedRevisions.txt
    echo "src-bar http://fake/url/bar 4321" >> ${ws}/bld-externalComponents-fcmd/usedRevisions.txt


}
tearDown() {
    true
}

test1() {
    assertTrue "createRebuildScript fcmd"

    # just check result file
    local expect=$(createTempFile)
cat <<EOF > ${expect}
#!/bin/bash
# script was automatically created by jenkins job LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd / 1
# for details ask PS LFS SCM
# This script is for fcmd

set -o errexit
set -o allexport
set -o nounset
mkdir workdir-fcmd
cd workdir-fcmd
mkdir -p bld bldtools locations .build_workdir
ln -sf /build/home/SC_LFS/sdk/tags/SDK3_123 bld/sdk3
ln -sf /build/home/SC_LFS/pkgpool/PKGPOOL_1234 bld/pkgpool
svn checkout -r 1234 http://fake/url/foo src-foo
svn checkout -r 4321 http://fake/url/bar src-bar
echo done
exit 0
EOF
    assertEquals "$(cat ${expect})" \
                 "$(cat ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/workdir_fcmd.sh)"

    return
}

source lib/shunit2

exit 0

