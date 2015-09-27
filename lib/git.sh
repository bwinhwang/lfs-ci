#!/bin/bash
## @file  git.sh
#  @brief wrapper functions for git

LFS_CI_SOURCE_git='$Id$'

## @fn      gitLog()
#  @brief   get the log from git
#  @param   {arguments}    arguments for git log
#  @return  log from git
gitLog() {
    execute -n git log $@
    return 0
}

## @fn      gitTagAndPushToOrigin()
#  @brief   creates a tag in git and push the tag to the origin
#  @param   {tagName}    name of the tag
#  @return  <none>
gitTagAndPushToOrigin() {
    local tagName=$1
    mustHaveValue "${tagName}" "tagName"
    execute git tag -a -m "new tag ${tagName}" ${tagName}
    execute git push origin ${tagName}
    return 0
}

## @fn      gitReset()
#  @brief   perform a git reset command
#  @param   {arguments}    arguments for git reset
#  @return  <none>
gitReset() {
    execute git reset $@
    return 0
}

## @fn      gitDescribe()
#  @brief   get the description from git
#  @param   {arguments}    arguments for git describe
#  @return  description from git
gitDescribe() {
    execute -n git describe $@
    return 0
}

## @fn      gitRevParse()
#  @brief   perform the git rev-parse command
#  @param   {arguments}    arguments for git rev-parse
#  @return  <none>
gitRevParse() {
    execute -n git rev-parse $@
    return 0
}

## @fn      gitClone()
#  @brief   perform the git clone command
#  @param   {arguments}    arguments for git clone
#  @return  <none>
gitClone() {
    execute git clone $@
    return 0
}

## @fn      gitCheckout()
#  @brief   perform the git checkout command
#  @param   {arguments}    arguments for git checkout
#  @return  <none>
gitCheckout() {
    execute git checkout $@
    return 0
}

## @fn      gitSubmodule()
#  @brief   perform the git submodule command
#  @param   {arguments}    arguments for git submodule
#  @return  <none>
gitSubmodule() {
    execute git submodule $@
    return 0
}
