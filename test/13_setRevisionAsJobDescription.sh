#!/bin/bash

export LFS_CI_ROOT="."

. lib/common.sh
. lib/jenkins.sh

oneTimeSetUp() {
  cp test/data/13_setRevisionAsJobDescription.xml test/data/13_setRevisionAsJobDescription.xml.bak
}

oneTimeTearDown() {
  mv test/data/13_setRevisionAsJobDescription.xml.bak test/data/13_setRevisionAsJobDescription.xml
}

testDescription() {
  setRevisionAsJobDescription Test_Job test/data/13_setRevisionAsJobDescription.xml FB1411
  assertEquals "Number of description is not 1." 1 $(grep 114389 test/data/13_setRevisionAsJobDescription.xml | wc -l)
}

#oneTimeSetUp
#oneTimeTearDown
#testDescription
. lib/shunit2
