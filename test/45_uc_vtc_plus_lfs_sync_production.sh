#!/bin/bash

source test/common.sh
source lib/uc_vtc_plus_lfs.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getWorkspaceName() {
        mockedCommand "getWorkspaceName $@"
        rm -rf ${WORKSPACE}/workspace/
        mkdir -p ${WORKSPACE}/workspace/
        echo ${WORKSPACE}/workspace
    }
    mustHaveWorkspaceName() {
        mockedCommand "mustHaveWorkspaceName $@"
    }
    execute() {
        mockedCommand "execute $@"
        # we want to create directories...
        if [[ $1 == mkdir ]] ; then 
            $@
        fi
    }
    mustHavePreparedWorkspace() {
        mockedCommand "mustHavePreparedWorkspace $@"
    }
    mustHaveNextCiLabelName() {
        mockedCommand "mustHaveNextCiLabelName $@"
    }
    getNextCiLabelName() {
        mockedCommand "getNextCiLabelName $@"
        echo LABEL
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_UC_package_copy_to_share_real_location)
                echo ${UT_PRODUCTION_SHARE}
            ;;
            LFS_CI_uc_vtc_plus_lfs_files_to_sync)
                echo path1 path2 path3
            ;;
            LFS_CI_uc_vtc_plus_lfs_remote_server)
                echo remote.server.name
            ;;
            LFS_CI_uc_vtc_plus_lfs_remote_path)
                echo remote/path/name
            ;;
        esac                
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export UT_PRODUCTION_SHARE=$(createTempDirectory)
    mkdir -p ${UT_PRODUCTION_SHARE}/LABEL
    export JOB_NAME=LFS_CI_-_trunk_-_foobar
    export BUILD_NUMBER=1234
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_foobar2
    export UPSTREAM_BUILD=123
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_VTC_PLUS_LFS_SYNC_PRODUCTION"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getWorkspaceName 
mustHaveWorkspaceName 
mustHavePreparedWorkspace 
mustHaveNextCiLabelName 
getNextCiLabelName 
getConfig LFS_CI_UC_package_copy_to_share_real_location
execute -n ${LFS_CI_ROOT}/bin/xpath -q -e /versionControllFile/file/@source ${UT_PRODUCTION_SHARE}/LABEL/os/version_control.xml
getConfig LFS_CI_uc_vtc_plus_lfs_files_to_sync
getConfig LFS_CI_uc_vtc_plus_lfs_remote_server
getConfig LFS_CI_uc_vtc_plus_lfs_remote_path
execute rsync --archive --verbose --recursive --partial --progress --rsh=ssh --files-from=${WORKSPACE}/workspace/filelist_to_sync ${UT_PRODUCTION_SHARE}/LABEL remote.server.name:remote/path/name/LABEL
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
