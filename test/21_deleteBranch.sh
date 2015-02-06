#!/bin/bash

. lib/common.sh
. lib/logging.sh

oneTimeSetUp() {
    export BRANCH="FB1408"
    . scripts/deleteBranch.sh
}

oneTimeTearDown() {
    echo
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
  assertEquals "Branch type does not match." "MD" "${branchType}"
  local yy=$(getBranchPart MD11408 YY)
  assertEquals "Branch YY does not match." "14" "$yy"
  local yyyy=$(getBranchPart MD11408 YYYY)
  assertEquals "Branch YYYY does not match." "2014" "$yyyy"
  local mm=$(getBranchPart MD11408 MM)
  assertEquals "Branch MM does not match." "08" "$mm"
  local nr=$(getBranchPart MD11408 NR)
  assertEquals "Branch NR does not match." "1" "$nr"
}

test_getEclValue() {
    local value=$(getEclValue "ECL_PS_LFS_OS" ${BRANCH})
    assertEquals "BRANCH form ECL does not match." "FB_PS_LFS_OS_2014_08_0222" "${value}"
}

test_getEclValueLRC() {
    local value=$(getEclValue "ECL_PS_LRC_LCP_LFS_OS" ${BRANCH})
    assertEquals "BRANCH form ECL does not match." "FB_LRC_LCP_PS_LFS_OS_2014_08_0155" "${value}"
}

. lib/shunit2
