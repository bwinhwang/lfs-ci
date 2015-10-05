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
echo "lfsSourceRepos = ${reposUrl}"                                             > ${LFS_CI_CONFIG_FILE}
echo "LFS_CI_global_mapping_location < job_location:trunk > = pronb-developer" >> ${LFS_CI_CONFIG_FILE}
echo "LFS_CI_global_mapping_branch_location < branchName:trunk > = pronb-developer" >> ${LFS_CI_CONFIG_FILE}
echo "svnMasterServerHostName <> = $repos" >> ${LFS_CI_CONFIG_FILE}
echo "svnSlaveServerUlmHostName <> = $repos" >> ${LFS_CI_CONFIG_FILE}

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
    echo "src-foo ${reposUrl}/os/trunk/main/src-foo 4"                                     >> ${REVISION_STATE_FILE}
    printf "bld-buildtools ${reposUrl}/os/trunk/bldtools/bld-buildtools-common 3"          >> ${REVISION_STATE_FILE}

    assertTrue "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testChangeTriggerBuild() {
    echo "location ${reposUrl}/os/trunk/bldtools/locations-pronb-developer/Dependencies 4"  > ${REVISION_STATE_FILE}
    # different revision
    echo "src-foo ${reposUrl}/os/trunk/main/src-foo 5"                                     >> ${REVISION_STATE_FILE}
    echo "bld-buildtools ${reposUrl}/os/trunk/bldtools/bld-buildtools-common 3"            >> ${REVISION_STATE_FILE}

    assertFalse "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testChangeWithKeywordNoBuild() {
 
    local workspace=$(createTempDirectory)
    assertTrue "svn co -q ${reposUrl} ${workspace}"
    echo b > ${workspace}/os/trunk/main/src-foo/file
    assertTrue "svn ci -q -m 'BTSPS-1657: commit with keyword' ${workspace}"

    assertFalse "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testChangeWithKeywordNoBuild2() {
 
    local workspace=$(createTempDirectory)
    assertTrue "svn co -q ${reposUrl} ${workspace}"
    echo c > ${workspace}/os/trunk/main/src-foo/file
    local comment=$(createTempFile)
    echo "BTSPS-1657: commit with keywort" > ${comment}
    echo "" >> ${comment}
    assertTrue "svn ci -q -F ${comment} ${workspace}"

}

testChangeWithoutKeywordBuild() {
 
    echo "location ${reposUrl}/os/trunk/bldtools/locations-pronb-developer/Dependencies 4"  > ${REVISION_STATE_FILE}
    # different revision
    echo "src-foo ${reposUrl}/os/trunk/main/src-foo 6"                                     >> ${REVISION_STATE_FILE}
    echo "bld-buildtools ${reposUrl}/os/trunk/bldtools/bld-buildtools-common 3"            >> ${REVISION_STATE_FILE}

    local workspace=$(createTempDirectory)
    assertTrue "svn co -q ${reposUrl} ${workspace}"
    echo d > ${workspace}/os/trunk/main/src-foo/file
    assertTrue "svn ci -m 'commit without keyword' ${workspace}"
    assertTrue "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testNoRevisionStateFile() {
    assertTrue "rm -rf ${REVISION_STATE_FILE}"

    assertFalse "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testSubversionErrorOldRevision() {
    echo "location ${reposUrl}/os/trunk/bldtools/locations-pronb-developer/Dependencies 4" >> ${REVISION_STATE_FILE}
    echo "src-foo ${reposUrl}/os/trunk/main/src-foo 9999999"                                     >> ${REVISION_STATE_FILE}
    printf "bld-buildtools ${reposUrl}/os/trunk/bldtools/bld-buildtools-common 3"          >> ${REVISION_STATE_FILE}

    assertFalse "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}

testNoRevisionStateFileVariableBuild() {
    unset REVISION_STATE_FILE
    export REVISION_STATE_FILE

    assertTrue "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
}


testTwoLocationsBuild() {
    # the feature does not work, so we do not need any test
#     local workspace=$(createTempDirectory)
# 
#     svn mkdir -q -m "new dir" --parents ${reposUrl}/os/trunk/bldtools/locations-FSM_R4_DEV
#     svn mkdir -q -m "new dir" --parents ${reposUrl}/os/trunk/main/src-bar
#     svn co -q ${reposUrl} ${workspace}
# 
#     local deps=${workspace}/os/trunk/bldtools/locations-FSM_R4_DEV/Dependencies
#     echo "dir src-bar"                                        > ${deps}
#     echo "svn-repository @REPOS ${reposUrl}"                 >> ${deps}
#     echo 'search-trunk  src-*   @REPOS/os/trunk/main/${DIR}' >> ${deps}
#     svn add -q ${deps}
#     svn commit -q -m "add new location" ${workspace}
# 
#     echo a > ${workspace}/os/trunk/main/src-bar/file
#     svn add -q ${workspace}/os/trunk/main/src-bar/file
#     svn commit -q -m "change file" ${workspace}
# 
#     echo "CUSTOM_SCM_svn_additional_location = FSM_R4_DEV" >> ${LFS_CI_CONFIG_FILE}
#     assertTrue "${LFS_CI_ROOT}/bin/customSCM.svn.sh compare"
    true
}

source lib/shunit2

exit 0

