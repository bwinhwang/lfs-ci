#!/bin/bash

. lib/common.sh
. lib/jenkins.sh

initTempDirectory

oneTimeSetUp() {
  cp test/data/13_setRevisionAsJobDescription.xml test/data/13_setRevisionAsJobDescription.xml.bak
}

oneTimeTearDown() {
  mv test/data/13_setRevisionAsJobDescription.xml.bak test/data/13_setRevisionAsJobDescription.xml
}

testDescription() {
  svnLog() {
      cat test/data/13_setRevisionAsJobDescription.svn.xml
  }
  setRevisionAsJobDescription test/data/13_setRevisionAsJobDescription.xml BranchName
  assertEquals "Number of description is not 1." 1 $(grep 114389 test/data/13_setRevisionAsJobDescription.xml | wc -l)
}

testFail() {
  svnLog() {
      cat test/data/13_setRevisionAsJobDescription_wrong.svn.xml
  }
  setRevisionAsJobDescription test/data/13_setRevisionAsJobDescription.xml BranchName
  assertEquals "Number of description is not 0." 0 $(grep 114389 test/data/13_setRevisionAsJobDescription.xml | wc -l)
}

. lib/shunit2
