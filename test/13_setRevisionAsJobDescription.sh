#!/bin/bash

. lib/common.sh
. lib/jenkins.sh

initTempDirectory

oneTimeSetUp() {
  cp test/data/13_setRevisionAsJobDescription.xml test/data/13_setRevisionAsJobDescription.xml.bak
  svnLog() {
      cat test/data/13_setRevisionAsJobDescription.svn.xml
  }
}

oneTimeTearDown() {
  mv test/data/13_setRevisionAsJobDescription.xml.bak test/data/13_setRevisionAsJobDescription.xml
}

testDescription() {
  setRevisionAsJobDescription test/data/13_setRevisionAsJobDescription.xml BranchName
  assertEquals "Number of description is not 1." 1 $(grep 114389 test/data/13_setRevisionAsJobDescription.xml | wc -l)
}

#oneTimeSetUp
#oneTimeTearDown
#testDescription
. lib/shunit2
