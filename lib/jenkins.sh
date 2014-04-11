#!/bin/bash


executeJenkinsCli() {
    execute ${java} -jar ${jenkinsCli} -s "${jenkinsMasterServerHttpUrl}" "$@"
}

setBuildDescription() {
    local jobName=$1
    local buildNumber=$2
    local description="$3"

    executeJenkinsCli "${jobName}" "${buildNumber}" "${description}"

    return
}

