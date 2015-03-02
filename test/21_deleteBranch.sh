#!/bin/bash

. lib/common.sh
. lib/logging.sh

oneTimeSetUp() {
    export BRANCH="FB1408"
    export LfS_CI_ROOT="."
    svn() {
        if [[ $(echo "$@" | grep FB1408) ]]; then
            cat test/data/21_deleteBranchFB1408.txt
            return 1
        else
            cat test/data/21_deleteBranchMB.txt
            return 0
        fi
    }
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

test_getEclValue() {
    local value=$(getValueFromEclFile "ECL_PS_LFS_OS" MAINBRANCH | tail -1)
    assertEquals "Did not get a value from ECL." "PS_LFS_OS_2015_02_0385" "${value}"
}
 
test_getEclValueLRC() {
    local value=$(getValueFromEclFile "ECL_PS_LRC_LCP_LFS_OS" MAINBRANCH | tail -1)
    assertEquals "Did not get a value from ECL." "LRC_LCP_PS_LFS_OS_2015_03_0006" "${value}"
}

test_getEclValueObsolete() {
    local value=$(getValueFromEclFile "ECL_PS_LFS_OS" FB1408 | tail -1)
    assertEquals "Did not get a value from ECL." "FB_PS_LFS_OS_2014_08_0222" "${value}"
}

test_getEclValueObsoleteLRC() {
    local value=$(getValueFromEclFile "ECL_PS_LRC_LCP_LFS_OS" FB1408 | tail -1)
    assertEquals "Did not get a value from ECL." "FB_LRC_LCP_PS_LFS_OS_2014_08_0155" "${value}"
}

. lib/shunit2
