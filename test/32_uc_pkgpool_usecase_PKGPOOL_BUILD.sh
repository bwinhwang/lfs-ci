#!/bin/bash

source test/common.sh

source lib/uc_pkgpool.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    gitReset() {
        mockedCommand "gitReset $@"
    }
    gitTagAndPushToOrigin() {
        mockedCommand "gitTagAndPushToOrigin $@"
    }
    gitDescribe() {
        mockedCommand "gitDescribe $@"
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    execute() {
        mockedCommand "execute $@"
        if [[ $2 = sed ]] ; then
            echo PKGPOOL_FOO
        fi
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    mustHaveCleanWorkspace() {
        mkdir -p ${WORKSPACE}/workspace
    }
    createTempFile() {
        echo "TempFile"
    }
    getConfig() {
        case $1 in 
            PKGPOOL_CI_uc_build_can_create_tag_in_git) echo ${UT_CAN_RELEASE} ;;
            *) echo $1 ;;
        esac
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=PKGPOOL_CI_-_trunk_-_Build
    export BUILD_NUMBER=123
    mkdir ${WORKSPACE}/src/
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

test1() {
    export UT_CAN_RELEASE=1

    assertTrue "usecase_PKGPOOL_BUILD"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/src/src
gitReset --hard
execute ./bootstrap
execute -l TempFile ${WORKSPACE}/src/build PKGPOOL_additional_build_parameters
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
execute cp TempFile ${WORKSPACE}/workspace/bld/bld-pkgpool-release/build.log
execute cp -a ${WORKSPACE}/workspace/logs ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
execute -n sed -ne s,^\(\[[0-9 :-]*\] \)\?release \([^ ]*\) complete,\2,p TempFile
gitDescribe --abbrev=0
gitTagAndPushToOrigin PKGPOOL_FOO
execute -n git rev-parse HEAD
setBuildDescription PKGPOOL_CI_-_trunk_-_Build 123 PKGPOOL_FOO
execute -n sed -ne s|^src [^ ]* \(.*\)$|PS_LFS_PKG = \1|p ${WORKSPACE}/workspace/pool/*.meta
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_CAN_RELEASE=

    assertTrue "usecase_PKGPOOL_BUILD"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/src/src
gitReset --hard
execute ./bootstrap
execute -l TempFile ${WORKSPACE}/src/build PKGPOOL_additional_build_parameters
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
execute cp TempFile ${WORKSPACE}/workspace/bld/bld-pkgpool-release/build.log
execute cp -a ${WORKSPACE}/workspace/logs ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
