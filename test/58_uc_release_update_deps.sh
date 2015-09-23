#!/bin/bash

source test/common.sh
source lib/uc_release_update_deps.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in 
            LFS_CI_uc_release_can_commit_depencencies) echo ${UT_CAN_COMMIT} ;;
            *) echo $1 ;;
        esac
    }
    execute() {
        mockedCommand "execute $@"
        if [[ $2 == sort ]] ; then
            shift
            $@
        fi
    }
    mustBePreparedForReleaseTask() {
        mockedCommand "mustBePreparedForReleaseTask $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/
        mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-fspc/
        echo "src-test http://svnUrl/src-test 1234" \
            >> ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/usedRevisions.txt
        echo "src-foobar http://svnUrl/src-foobar 1234" \
            >> ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/usedRevisions.txt
        echo "src-bar http://svnUrl/src-bar 1234" \
            >> ${WORKSPACE}/workspace/bld/bld-externalComponents-fspc/usedRevisions.txt
        echo "bld-foo http://svnUrl/src-foo 1234" \
            >> ${WORKSPACE}/workspace/bld/bld-externalComponents-fspc/usedRevisions.txt
        find ${WORKSPACE}
    }
    svnCheckout() {
        mockedCommand "svnCheckout $@"
        local name=$(basename $3)
        mkdir -p ${WORKSPACE}/workspace/${name}
        case ${name} in 
            src-test)   touch ${WORKSPACE}/workspace/${name}/Dependencies ;;
            src-foobar) touch ${WORKSPACE}/workspace/${name}/Buildfile    ;;
            src-bar)    touch ${WORKSPACE}/workspace/${name}/Dependencies ;;
            bld-foo)    touch ${WORKSPACE}/workspace/${name}/Dependencies ;;
        esac
        return
    }
    svnCommit() {
        mockedCommand "svnCommit $@"
    }
    svnDiff() {
        mockedCommand "svnDiff $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)

    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_BUILD_NAME
    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME=PS_LFS_OS_OLD_BUILD_NAME

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_CAN_COMMIT=1
    assertTrue "usecase_LFS_RELEASE_UPDATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
execute -n sort -u ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/usedRevisions.txt ${WORKSPACE}/workspace/bld/bld-externalComponents-fspc/usedRevisions.txt
getConfig LFS_CI_uc_release_can_commit_depencencies
execute rm -rf ${WORKSPACE}/workspace/src-bar
svnCheckout --depth=immediates --ignore-externals http://svnUrl/src-bar ${WORKSPACE}/workspace/src-bar
getConfig LFS_PROD_uc_release_update_deps_build_name_part
execute perl -p -i -e s/\b[A-Z0-9_]*LFS_PROD_uc_release_update_deps_build_name_part\S+\b/PS_LFS_OS_BUILD_NAME/g ${WORKSPACE}/workspace/src-bar/Dependencies
svnDiff ${WORKSPACE}/workspace/src-bar/Dependencies
getConfig LFS_PROD_uc_release_svn_message_template -t releaseName:PS_LFS_OS_BUILD_NAME -t oldReleaseName:PS_LFS_OS_OLD_BUILD_NAME -t revision:1234
svnCommit -F ${WORKSPACE}/workspace/commitMessage ${WORKSPACE}/workspace/src-bar/Dependencies
execute rm -rf ${WORKSPACE}/workspace/src-foobar
svnCheckout --depth=immediates --ignore-externals http://svnUrl/src-foobar ${WORKSPACE}/workspace/src-foobar
execute rm -rf ${WORKSPACE}/workspace/src-test
svnCheckout --depth=immediates --ignore-externals http://svnUrl/src-test ${WORKSPACE}/workspace/src-test
getConfig LFS_PROD_uc_release_update_deps_build_name_part
execute perl -p -i -e s/\b[A-Z0-9_]*LFS_PROD_uc_release_update_deps_build_name_part\S+\b/PS_LFS_OS_BUILD_NAME/g ${WORKSPACE}/workspace/src-test/Dependencies
svnDiff ${WORKSPACE}/workspace/src-test/Dependencies
getConfig LFS_PROD_uc_release_svn_message_template -t releaseName:PS_LFS_OS_BUILD_NAME -t oldReleaseName:PS_LFS_OS_OLD_BUILD_NAME -t revision:1234
svnCommit -F ${WORKSPACE}/workspace/commitMessage ${WORKSPACE}/workspace/src-test/Dependencies
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_CAN_COMMIT=
    assertTrue "usecase_LFS_RELEASE_UPDATE_DEPS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
execute -n sort -u ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/usedRevisions.txt ${WORKSPACE}/workspace/bld/bld-externalComponents-fspc/usedRevisions.txt
getConfig LFS_CI_uc_release_can_commit_depencencies
execute rm -rf ${WORKSPACE}/workspace/src-bar
svnCheckout --depth=immediates --ignore-externals http://svnUrl/src-bar ${WORKSPACE}/workspace/src-bar
getConfig LFS_PROD_uc_release_update_deps_build_name_part
execute perl -p -i -e s/\b[A-Z0-9_]*LFS_PROD_uc_release_update_deps_build_name_part\S+\b/PS_LFS_OS_BUILD_NAME/g ${WORKSPACE}/workspace/src-bar/Dependencies
svnDiff ${WORKSPACE}/workspace/src-bar/Dependencies
execute rm -rf ${WORKSPACE}/workspace/src-foobar
svnCheckout --depth=immediates --ignore-externals http://svnUrl/src-foobar ${WORKSPACE}/workspace/src-foobar
execute rm -rf ${WORKSPACE}/workspace/src-test
svnCheckout --depth=immediates --ignore-externals http://svnUrl/src-test ${WORKSPACE}/workspace/src-test
getConfig LFS_PROD_uc_release_update_deps_build_name_part
execute perl -p -i -e s/\b[A-Z0-9_]*LFS_PROD_uc_release_update_deps_build_name_part\S+\b/PS_LFS_OS_BUILD_NAME/g ${WORKSPACE}/workspace/src-test/Dependencies
svnDiff ${WORKSPACE}/workspace/src-test/Dependencies
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
