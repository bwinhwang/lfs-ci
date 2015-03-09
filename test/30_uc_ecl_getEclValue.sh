#!/bin/bash

source lib/common.sh

initTempDirectory

source lib/uc_ecl.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    mustHaveNextCiLabelName() {
        mockedCommand "mustHaveNextCiLabelName $@"
    }
    getNextCiLabelName() {
        mockedCommand "getNextCiLabelName $@"
        echo PS_LFS_OS_label
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            SVN_lfs_branch_name)
                echo svn_branch_name
            ;;
            sdk3)
                echo PS_LFS_SDK3_label
            ;;
        esac
    }
}
oneTimeTearDown() {
    true
}
setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
    touch  ${UT_MOCKED_COMMANDS}
}
tearDown() {
    true 
}

test1() {
    local value=$(getEclValue ECL_PS_LFS_REL oldValue)
    assertEquals "${value}" "PS_LFS_REL_label"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustHaveNextCiLabelName 
getNextCiLabelName 
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test2() {
    local value=$(getEclValue ECL_PS_LRC_LCP_LFS_REL oldValue)
    assertEquals "${value}" "PS_LFS_REL_label"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustHaveNextCiLabelName 
getNextCiLabelName 
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test3() {
    local value=$(getEclValue ECL_PS_LFS_OS oldValue)
    assertEquals "${value}" "PS_LFS_OS_label"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustHaveNextCiLabelName 
getNextCiLabelName 
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test4() {
    local value=$(getEclValue ECL_PS_LRC_LCP_LFS_OS oldValue)
    assertEquals "${value}" "PS_LFS_OS_label"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustHaveNextCiLabelName 
getNextCiLabelName 
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test5() {
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/
    echo "a b PS_LFS_SDK3_label" > ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents

    local value=$(getEclValue ECL_PS_LFS_SDK3 oldValue)
    assertEquals "${value}" "PS_LFS_SDK3_label"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig sdk3 -f ${WORKSPACE}/workspace/bld//bld-externalComponents-summary/externalComponents
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test6() {
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-asdf/
    echo "a b 1234" > ${WORKSPACE}/workspace/bld/bld-externalComponents-asdf/usedRevisions.txt

    local value=$(getEclValue ECL_LFS oldValue)
    assertEquals "${value}" "svn_branch_name\@1234"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getConfig SVN_lfs_branch_name
mustHaveNextCiLabelName 1234 revision
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test7() {
    local value=$(getEclValue ECL_PS_LFS_INTERFACE_REV 1234)
    assertEquals "${value}" "1235"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

test8() {
    assertFalse "getEclValue asdf oldValue"
    return
}

source lib/shunit2

exit 0

