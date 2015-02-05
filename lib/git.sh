#!/bin/bash

gitLog() {
    execute -n git log
}

gitTagAndPushToOrigin() {
    local tagName=$1
    mustHaveValue "${tagName}" "tagName"
    execute git tag -a -m "new tag ${tagName}" ${tagName}
    execute git push origin ${tagName}
    return
}

gitReset() {
    execute git reset $@
    return
}

gitDescribe() {
    execute -n git describe $@
}
