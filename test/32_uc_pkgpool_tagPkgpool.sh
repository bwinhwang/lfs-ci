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
        local cnt=$(cat ${UT_TMPDIR}/.cnt)
        cnt=$((cnt + 1 ))
        echo ${cnt} > ${UT_TMPDIR}/.cnt
        touch ${UT_TMPDIR}/tmp.${cnt}
        echo ${UT_TMPDIR}/tmp.${cnt}
    }
    getConfig() {
        echo ${UT_CAN_RELEASE}
    }
    gitDescribe() {
        echo gitRevision
    }
    gitTagAndPushToOrigin() {
        mockedCommand "gitTagAndPushToOrigin $@"
    }
    gitRevParse() {
        echo "gitRevParserRev"
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=PKGPOOL_CI_-_trunk_-_Build
    export BUILD_NUMBER=123
    mkdir -p ${WORKSPACE}/src/
    mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
    export UT_TMPDIR=$(createTempDirectory)
    echo 0 > ${UT_TMPDIR}/.cnt
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    rm -rf ${UT_TMPDIR}
    return
}

test1() {
    export UT_CAN_RELEASE=1
    local file=$(createTempFile)
    assertTrue "_tagPkgpool ${file}"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n sed -ne s,^\(\[[0-9 :-]*\] \)\?release \([^ ]*\) complete,\2,p ${UT_TMPDIR}/tmp.1
gitTagAndPushToOrigin PKGPOOL_FOO
setBuildDescription PKGPOOL_CI_-_trunk_-_Build 123 PKGPOOL_FOO
execute -n sed -ne s|^src [^ ]* \(.*\)$|PS_LFS_PKG = \1|p ${WORKSPACE}/workspace/pool/*.meta
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_CAN_RELEASE=
    local file=$(createTempFile)
    assertTrue "_tagPkgpool ${file}"

    # no commands are exectued!
    local expect=$(createTempFile)
    cat <<EOF > ${expect}
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
