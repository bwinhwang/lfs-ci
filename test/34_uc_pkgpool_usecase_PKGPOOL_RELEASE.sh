#!/bin/bash

source test/common.sh

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
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    execute() {
        mockedCommand "execute $@"
    }
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
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
    copyFileFromBuildDirectoryToWorkspace() {
        mockedCommand "copyFileFromBuildDirectoryToWorkspace $@"
    }
    copyFileToArtifactDirectory() {
        mockedCommand "copyFileToArtifactDirectory $@"
    }
    runOnMaster() {
        mockedCommand "runOnMaster $@"
        return 0
    }
    copyFileFromBuildDirectoryToWorkspace() {
        mockedCommand "copyFileFromBuildDirectoryToWorkspace $@"
        touch ${WORKSPACE}/$3
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
    export JOB_NAME=PKGPOOL_PROD_-_trunk_-_Release
    export BUILD_NUMBER=1234
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234

    mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
    echo LABEL > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/label
    echo OLD_LABEL > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/oldLabel

    usecase_PKGPOOL_RELEASE

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 pkgpool
runOnMaster test -e /var/fpwork/psulm/lfs-jenkins/home/jobs/PKGPOOL_PROD_-_trunk_-_Release/builds/lastSuccessfulBuild/forReleaseNote.txt
copyFileFromBuildDirectoryToWorkspace PKGPOOL_PROD_-_trunk_-_Release lastSuccessfulBuild forReleaseNote.txt
execute mv ${WORKSPACE}/forReleaseNote.txt ${WORKSPACE}/workspace/forReleaseNote.txt.old
setBuildDescription PKGPOOL_PROD_-_trunk_-_Release 1234 LABEL
execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t LABEL -o OLD_LABEL -f ${LFS_CI_ROOT}/etc/file.cfg
mustBeValidXmlReleaseNote ${WORKSPACE}/workspace/releasenote.xml
execute -i -l ${WORKSPACE}/workspace/releasenote.txt diff -y -W72 -t --suppress-common-lines ${WORKSPACE}/workspace/forReleaseNote.txt.old ${WORKSPACE}/workspace/bld/bld-pkgpool-release/forReleaseNote.txt
createReleaseInWorkflowTool LABEL ${WORKSPACE}/workspace/releasenote.xml
uploadToWorkflowTool LABEL ${WORKSPACE}/workspace/releasenote.xml
execute ${LFS_CI_ROOT}/bin/sendReleaseNote -r ${WORKSPACE}/workspace/os/releasenote.txt -t -f ${LFS_CI_ROOT}/etc/file.cfg
copyFileToArtifactDirectory ${WORKSPACE}/workspace/releasenote.xml
copyFileToArtifactDirectory ${WORKSPACE}/workspace/releasenote.txt
copyFileFromBuildDirectoryToWorkspace ${WORKSPACE}/workspace/bld/bld-pkgpool-release/forReleaseNote.txt
linkFileToArtifactsDirectory /build/home/psulm/LFS_internal/artifacts/PKGPOOL_PROD_-_trunk_-_Release/1234
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
