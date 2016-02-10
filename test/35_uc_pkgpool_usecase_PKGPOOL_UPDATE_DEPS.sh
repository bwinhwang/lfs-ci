#!/bin/bash

source test/common.sh

source lib/uc_pkgpool.sh

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
        case $1 in 
            PKGPOOL_PROD_update_dependencies_svn_url) 
                echo ${UT_CONFIG_URLS}
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
        echo newRevision > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/gitrevision
        return
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    gitRevParse() {
        mockedCommand "gitRevParse $@"
        echo "$1"
    }
    gitClone() {
        mockedCommand "gitClone $@"
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
            cat ${WORKSPACE}/svn_error_1 > ${LFS_CI_LAST_EXECUTE_LOGFILE}
            rm -rf ${WORKSPACE}/svn_error_1
            exit 1
        fi
        if [[ -e ${WORKSPACE}/svn_error_2 ]] ; then
            cat ${WORKSPACE}/svn_error_2 > ${LFS_CI_LAST_EXECUTE_LOGFILE}
            rm -rf ${WORKSPACE}/svn_error_2
            exit 1
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
    export UT_CONFIG_URLS=http://host/path/file
    export BUILD_NUMBER=123
    export JOB_NAME=LFS_CI_-_trunk_-_Build

    export UT_SVN_EXIT_CODE=0

    mkdir -p ${WORKSPACE}/src

    assertTrue "usecase_PKGPOOL_UPDATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 pkgpool
setBuildDescription LFS_CI_-_trunk_-_Build 123 LABEL
execute rm -rfv ${WORKSPACE}/src
getConfig PKGPOOL_git_repos_url
gitClone PKGPOOL_git_repos_url ${WORKSPACE}/src
getConfig PKGPOOL_PROD_update_dependencies_svn_url
mustHaveCleanWorkspace
svnCheckout http://host/path ${WORKSPACE}/workspace
gitLog --format=medium oldRevision..newRevision
execute sed -i -e 
            s|^PKGLABEL *?=.*|PKGLABEL ?= LABEL|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= LABEL|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool LABEL|
         ${WORKSPACE}/workspace/file
svnCommit -F ${WORKSPACE}/workspace/gitLog.txt ${WORKSPACE}/workspace/file ${WORKSPACE}/workspace/src/gitrevision
EOF

    assertExecutedCommands ${expect}

    return
}

test2() {
    # usecase: the commits will fail twice to svn
    # => result: exit 1 and failure of the usecase
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234
    export UT_CONFIG_URLS=http://host/path/file
    export BUILD_NUMBER=123
    export JOB_NAME=LFS_CI_-_trunk_-_Build

    echo "Error in line 1 : foobar asdf" > ${WORKSPACE}/svn_error_1
    echo "Error in line 2 : foobar asdf" > ${WORKSPACE}/svn_error_2

    mkdir -p ${WORKSPACE}/src

    # usecase_PKGPOOL_UPDATE_DEPS
    assertFalse "usecase_PKGPOOL_UPDATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 pkgpool
setBuildDescription LFS_CI_-_trunk_-_Build 123 LABEL
execute rm -rfv ${WORKSPACE}/src
getConfig PKGPOOL_git_repos_url
gitClone PKGPOOL_git_repos_url ${WORKSPACE}/src
getConfig PKGPOOL_PROD_update_dependencies_svn_url
mustHaveCleanWorkspace
svnCheckout http://host/path ${WORKSPACE}/workspace
gitLog --format=medium oldRevision..newRevision
execute sed -i -e 
            s|^PKGLABEL *?=.*|PKGLABEL ?= LABEL|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= LABEL|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool LABEL|
         ${WORKSPACE}/workspace/file
svnCommit -F ${WORKSPACE}/workspace/gitLog.txt ${WORKSPACE}/workspace/file ${WORKSPACE}/workspace/src/gitrevision
setBuildResultUnstable
execute sed -i -e 1{s,%,o/o,g;s,^,SVN REJECTED: ,} ${WORKSPACE}/workspace/gitLog.txt
svnCommit -F ${WORKSPACE}/workspace/gitLog.txt ${WORKSPACE}/workspace/file ${WORKSPACE}/workspace/src/gitrevision
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    # usecase: the commits will fail twice to svn
    # => result: exit 1 and failure of the usecase
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234
    export UT_CONFIG_URLS=http://host/path/file
    export BUILD_NUMBER=123
    export JOB_NAME=LFS_CI_-_trunk_-_Build

    echo "Error in line 1 : foobar asdf" > ${WORKSPACE}/svn_error_1

    mkdir -p ${WORKSPACE}/src

    assertTrue "usecase_PKGPOOL_UPDATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 pkgpool
setBuildDescription LFS_CI_-_trunk_-_Build 123 LABEL
execute rm -rfv ${WORKSPACE}/src
getConfig PKGPOOL_git_repos_url
gitClone PKGPOOL_git_repos_url ${WORKSPACE}/src
getConfig PKGPOOL_PROD_update_dependencies_svn_url
mustHaveCleanWorkspace
svnCheckout http://host/path ${WORKSPACE}/workspace
gitLog --format=medium oldRevision..newRevision
execute sed -i -e 
            s|^PKGLABEL *?=.*|PKGLABEL ?= LABEL|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= LABEL|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool LABEL|
         ${WORKSPACE}/workspace/file
svnCommit -F ${WORKSPACE}/workspace/gitLog.txt ${WORKSPACE}/workspace/file ${WORKSPACE}/workspace/src/gitrevision
setBuildResultUnstable
execute sed -i -e 1{s,%,o/o,g;s,^,SVN REJECTED: ,} ${WORKSPACE}/workspace/gitLog.txt
svnCommit -F ${WORKSPACE}/workspace/gitLog.txt ${WORKSPACE}/workspace/file ${WORKSPACE}/workspace/src/gitrevision
EOF
    assertExecutedCommands ${expect}

    return
}

test4() {
    # usecase: the commits will fail twice to svn
    # => result: exit 1 and failure of the usecase
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234
    export UT_CONFIG_URLS="http://host/path/file http://host/path2/file2"
    export BUILD_NUMBER=123
    export JOB_NAME=LFS_CI_-_trunk_-_Build

    mkdir -p ${WORKSPACE}/src

    assertTrue "usecase_PKGPOOL_UPDATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 pkgpool
setBuildDescription LFS_CI_-_trunk_-_Build 123 LABEL
execute rm -rfv ${WORKSPACE}/src
getConfig PKGPOOL_git_repos_url
gitClone PKGPOOL_git_repos_url ${WORKSPACE}/src
getConfig PKGPOOL_PROD_update_dependencies_svn_url
mustHaveCleanWorkspace
svnCheckout http://host/path ${WORKSPACE}/workspace
gitLog --format=medium oldRevision..newRevision
execute sed -i -e 
            s|^PKGLABEL *?=.*|PKGLABEL ?= LABEL|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= LABEL|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool LABEL|
         ${WORKSPACE}/workspace/file
svnCommit -F ${WORKSPACE}/workspace/gitLog.txt ${WORKSPACE}/workspace/file ${WORKSPACE}/workspace/src/gitrevision
mustHaveCleanWorkspace
svnCheckout http://host/path2 ${WORKSPACE}/workspace
gitLog --format=medium oldRevision..newRevision
execute sed -i -e 
            s|^PKGLABEL *?=.*|PKGLABEL ?= LABEL|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= LABEL|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool LABEL|
         ${WORKSPACE}/workspace/file2
svnCommit -F ${WORKSPACE}/workspace/gitLog.txt ${WORKSPACE}/workspace/file2 ${WORKSPACE}/workspace/src/gitrevision
EOF
    assertExecutedCommands ${expect}

    return
}

test5() {
    # fails. no auto correction possbile
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234
    export UT_CONFIG_URLS=http://host/path/file
    export BUILD_NUMBER=123
    export JOB_NAME=LFS_CI_-_trunk_-_Build

    mkdir -p ${WORKSPACE}/src
    echo "fail" > ${WORKSPACE}/svn_error_1

    assertTrue "usecase_PKGPOOL_UPDATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 pkgpool
setBuildDescription LFS_CI_-_trunk_-_Build 123 LABEL
execute rm -rfv ${WORKSPACE}/src
getConfig PKGPOOL_git_repos_url
gitClone PKGPOOL_git_repos_url ${WORKSPACE}/src
getConfig PKGPOOL_PROD_update_dependencies_svn_url
mustHaveCleanWorkspace
svnCheckout http://host/path ${WORKSPACE}/workspace
gitLog --format=medium oldRevision..newRevision
execute sed -i -e 
            s|^PKGLABEL *?=.*|PKGLABEL ?= LABEL|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= LABEL|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool LABEL|
         ${WORKSPACE}/workspace/file
svnCommit -F ${WORKSPACE}/workspace/gitLog.txt ${WORKSPACE}/workspace/file ${WORKSPACE}/workspace/src/gitrevision
setBuildResultUnstable
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
