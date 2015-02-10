#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/uc_pkgpool.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace"
        mkdir -p ${WORKSPACE}/workspace
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo 1>&2 foo $1
        case $1 in 
            PKGPOOL_PROD_uc_update_dependencies_svn_urls) 
                echo http://host/path/file
            ;;
            *) echo $1 ;;
        esac
        return
    }
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
        mkdir -p         ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
        echo LABEL >     ${WORKSPACE}/workspace/bld/bld-pkgpool-release/label
        echo OLD_LABEL > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/oldLabel
        return
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    gitRevParse() {
        mockedCommand "gitRevParse $@"
        echo "$1"
    }
    gitLog() {
        mockedCommand "gitLog $@"
    }
    execute() {
        mockedCommand "execute $@"
    }
    mustBeValidXmlReleaseNote() {
        mockedCommand "mustBeValidXmlReleaseNote $@"
    }
    uploadToWorkflowTool() {
        mockedCommand "uploadToWorkflowTool $@"
    }
    createReleaseInWorkflowTool() {
        mockedCommand "createReleaseInWorkflowTool $@"
    }
    linkFileToArtifactsDirectory() {
        mockedCommand "linkFileToArtifactsDirectory $@"
    }
    copyFileToArtifactDirectory() {
        mockedCommand "copyFileToArtifactDirectory $@"
    }
    svnCheckout() {
        mockedCommand "svnCheckout $@"
        mkdir -p ${WORKSPACE}/workspace/src/
        echo "oldRevision" > ${WORKSPACE}/workspace/src/gitrevision
        return
    }
    svnCommit() {
        mockedCommand "svnCommit $@"
        if [[ -e ${WORKSPACE}/svn_error_1 ]] ; then
            cat ${WORKSPACE}/svn_error_1
            return 1
        fi
        if [[ -e ${WORKSPACE}/svn_error_2 ]] ; then
            cat ${WORKSPACE}/svn_error_2
            return 1
        fi
    }
    setBuildResultUnstable() {
        mockedCommand "setBuildResultUnstable"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234

    export UT_SVN_EXIT_CODE=0

    mkdir -p ${WORKSPACE}/src

    assertTrue "usecase_PKGPOOL_UDPATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 pkgpool
setBuildDescription LABEL
getConfig PKGPOOL_PROD_uc_update_dependencies_svn_urls
svnCheckout http://host/path ${WORKSPACE}/workspace
gitRevParse HEAD
gitLog oldRevision..HEAD
execute -n sed -e s,^    %,%,
execute sed -i -e 
            s|^PKGLABEL *?=.*|PKGLABEL ?= |
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= |
            s|^hint *bld/pkgpool .*|hint bld/pkgpool |
         file
svnCommit -F gitlog file ${WORKSPACE}/workspace/src/gitrevision
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test2() {
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234

    echo "Error in line 12345 : foobar asdf" > ${WORKSPACE}/svn_error_1
    echo "Error in line 12345 : foobar asdf" > ${WORKSPACE}/svn_error_2

    mkdir -p ${WORKSPACE}/src

    assertTrue "usecase_PKGPOOL_UDPATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}
source lib/shunit2

exit 0
