#!/bin/bash

## @file  git.sh
#  @brief wrapper functions for git


## @fn      gitLog()
#  @brief   get the log from git
#  @param   {arguments}    arguments for git log
#  @return  log from git
gitLog() {
    execute -n git log
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
    return
}

## @fn      gitReset()
#  @brief   perform a git reset command
#  @param   {arguments}    arguments for git reset
#  @return  <none>
gitReset() {
    execute git reset $@
    return
}

## @fn      gitDescribe()
#  @brief   get the description from git
#  @param   {arguments}    arguments for git describe
#  @return  description from git
gitDescribe() {
    execute -n git describe $@
    return
}

gitRevParse() {
    execute git rev-parse $@
    return
}
