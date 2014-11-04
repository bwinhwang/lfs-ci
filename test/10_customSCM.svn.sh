#!/bin/bash

source lib/common.sh

initTempDirectory

export SHCOV=~/download/shcov-5/scripts/shcov

export repos=$(createTempDirectory)
export reposUrl=file://${repos}

export WORKSPACE=$(createTempDirectory)
export REVISION_STATE_FILE=$(createTempFile)
export OLD_REVISION_STATE_FILE=$(createTempFile)
export CHANGELOG=$(createTempFile)
export JOB_NAME="LFS_CI_-_trunk_-_Build"
export LFS_CI_CONFIG_FILE=$(createTempFile)
echo "lfsSourceRepos = ${reposUrl}" > ${LFS_CI_CONFIG_FILE}

oneTimeSetUp() {

    local workspace=$(createTempDirectory)

    svnadmin create ${repos}
    svn mkdir -q -m "new dir" --parents ${reposUrl}/os/trunk/bldtools/locations-pronb-developer
    svn mkdir -q -m "new dir" --parents ${reposUrl}/os/trunk/main/src-foo
    svn mkdir -q -m "new dir" --parents ${reposUrl}/os/trunk/bldtools/bld-buildtools-common
    svn co -q ${reposUrl} ${workspace}
    local deps=${workspace}/os/trunk/bldtools/locations-pronb-developer/Dependencies
    echo "dir src-foo"                                        > ${deps}
    echo "svn-repository @REPOS ${reposUrl}"                 >> ${deps}
    echo 'search-trunk  src-*   @REPOS/os/trunk/main/${DIR}' >> ${deps}
    svn add -q ${deps}
    svn commit -q -m "init" ${workspace}
    echo a > ${workspace}/os/trunk/main/src-foo/file
    svn add -q ${workspace}/os/trunk/main/src-foo/file
    svn commit -q -m "change file" ${workspace}
}
oneTimeTearDown() {
    rm -rf ${WORKSPACE}
    rm -rf ${workspace}
    rm -rf ${repos}
}

testNoChangeNoBuild() {
    echo "location ${reposUrl}/os/trunk/bldtools/locations-pronb-developer/Dependencies 4" >> ${REVISION_STATE_FILE}
    echo "src-foo ${reposUrl}/os/trunk/main/src-foo 5"                                     >> ${REVISION_STATE_FILE}
    printf "bld-buildtools ${reposUrl}/os/trunk/bldtools/bld-buildtools-common 3"          >> ${REVISION_STATE_FILE}

    assertFalse "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testChangeTriggerBuild() {
    echo "location ${reposUrl}/os/trunk/bldtools/locations-pronb-developer/Dependencies 4"  > ${REVISION_STATE_FILE}
    # different revision
    echo "src-foo ${reposUrl}/os/trunk/main/src-foo 5"                                     >> ${REVISION_STATE_FILE}
    echo "bld-buildtools ${reposUrl}/os/trunk/bldtools/bld-buildtools-common 3"            >> ${REVISION_STATE_FILE}

    assertFalse "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testSingleChangeWithKeywordNoBuild() {
 
    local workspace=$(createTempDirectory)
    assertTrue "svn co -q ${reposUrl} ${workspace}"
    echo b > ${workspace}/os/trunk/main/src-foo/file
    assertTrue "svn ci -q -m 'BTS-1657: commit with keyword' ${workspace}"

    assertFalse "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testTwoChangesWithKeywordNoBuild() {
 
    local workspace=$(createTempDirectory)
    assertTrue "svn co -q ${reposUrl} ${workspace}"
    echo c > ${workspace}/os/trunk/main/src-foo/file
    assertTrue "svn ci -q -m 'commit without keyword' ${workspace}"

    assertTrue "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testNoRevisionStateFile() {
    assertTrue "rm -rf ${REVISION_STATE_FILE}"

    assertFalse "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testNoRevisionStateFileVariable() {
    unset REVISION_STATE_FILE
    export REVISION_STATE_FILE

    assertTrue "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

source lib/shunit2

exit 0

