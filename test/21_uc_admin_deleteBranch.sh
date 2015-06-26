#!/bin/bash

. lib/common.sh
. lib/logging.sh
. lib/config.sh


initTempDirectory
export MOCKED_COMMAND=$(createTempFile)

oneTimeSetUp() {
    export TESTING="true"
    export LFS_CI_ROOT="."

    ssh() {
        echo ssh $* > $MOCKED_COMMAND
    }
}

oneTimeTearDown() {
    echo ""
}

test_deleteTestresults() {
    export BRANCH="FB1408"
    . bin/deleteBranch.sh
    deleteTestResults
    local expected="ssh ulegcpmoritz.emea.nsn-net.net rm -rf /lvol2/production_jenkins/test-repos/src-fsmtest/FB_PS_LFS_OS_2014_08_*"
    assertEquals "$(cat $MOCKED_COMMAND)" "$expected"
}

test_deleteTestresultsLRC() {
    export BRANCH="LRC_FB1502"
    . bin/deleteBranch.sh
    deleteTestResults
    local expected="ssh ulegcpmoritz.emea.nsn-net.net rm -rf /lvol2/production_jenkins/test-repos/src-fsmtest/FB_LRC_LCP_PS_LFS_OS_2015_02_*"
    assertEquals "$(cat $MOCKED_COMMAND)" "$expected"
}

test_deleteTestresultsSubBranch() {
    export BRANCH="FB1311_LNT4OPTUS"
    . bin/deleteBranch.sh
    deleteTestResults
    local expected="ssh ulegcpmoritz.emea.nsn-net.net rm -rf /lvol2/production_jenkins/test-repos/src-fsmtest/LNT4_OPTUS_PS_LFS_OS_2013_11_*"
    assertEquals "$(cat $MOCKED_COMMAND)" "$expected"
}

test_getBranchPartFB() {
  local branchType=$(getBranchPart FB1408 TYPE)
  assertEquals "Branch type does not match." "FB" "${branchType}"
  local yy=$(getBranchPart FB1408 YY)
  assertEquals "Branch YY does not match." "14" "$yy"
  local yyyy=$(getBranchPart FB1408 YYYY)
  assertEquals "Branch YYYY does not match." "2014" "$yyyy"
  local mm=$(getBranchPart FB1408 MM)
  assertEquals "Branch MM does not match." "08" "$mm"
}

test_getBranchPartMD() {
  local branchType=$(getBranchPart MD11408 TYPE)
  assertEquals "Branch type does not match." "MD1" "${branchType}"
  local yy=$(getBranchPart MD11408 YY)
  assertEquals "Branch YY does not match." "14" "$yy"
  local yyyy=$(getBranchPart MD11408 YYYY)
  assertEquals "Branch YYYY does not match." "2014" "$yyyy"
  local mm=$(getBranchPart MD11408 MM)
  assertEquals "Branch MM does not match." "08" "$mm"
  local nr=$(getBranchPart MD11408 NR)
  assertEquals "Branch NR does not match." "1" "$nr"
}

test_LRC_getBranchPartFB() {
  local branchType=$(getBranchPart LRC_FB1408 TYPE)
  assertEquals "Branch type does not match." "FB" "${branchType}"
  local yy=$(getBranchPart LRC_FB1408 YY)
  assertEquals "Branch YY does not match." "14" "$yy"
  local yyyy=$(getBranchPart LRC_FB1408 YYYY)
  assertEquals "Branch YYYY does not match." "2014" "$yyyy"
  local mm=$(getBranchPart LRC_FB1408 MM)
  assertEquals "Branch MM does not match." "08" "$mm"
}

. lib/shunit2
