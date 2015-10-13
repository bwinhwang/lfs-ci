#!/bin/bash

source lib/common.sh

test1() {
    branch="FB1512"
    result=$(branchMinusOne $branch)
    assertEquals $result "FB1511"
}

test2() {
    branch="FB1501"
    result=$(branchMinusOne $branch)
    assertEquals $result "FB1412"
}

test3() {
    branch="FB1510"
    result=$(branchMinusOne $branch)
    assertEquals $result "FB1509"
}

test4() {
    branch="FB1508"
    result=$(branchMinusOne $branch)
    assertEquals $result "FB1507"
}

test5() {
    branch="MD11512"
    result=$(branchMinusOne $branch)
    assertEquals $result "MD11511"
}

test6() {
    branch="MD11501"
    result=$(branchMinusOne $branch)
    assertEquals $result "MD11412"
}

test7() {
    branch="MD11510"
    result=$(branchMinusOne $branch)
    assertEquals $result "MD11509"
}

test8() {
    branch="MD11508"
    result=$(branchMinusOne $branch)
    assertEquals $result "MD11507"
}

source lib/shunit2
exit 0
