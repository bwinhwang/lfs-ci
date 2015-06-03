#!/bin/bash

getFingerprintOfCurrentJob() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    local upstreamJob=${UPSTREAM_PROJECT}
    mustHaveValue "${upstreamJob}" "upstream job name"

    local upstreamBuild=${UPSTREAM_BUILD}
    mustHaveValue "${upstreamBuild}" "upstream build number"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local file=${workspace}/bld/bld-fsmci-summary/label
    if [[ ! -e ${file} ]] ; then
        copyArtifactsToWorkspace ${upstreamJob} ${upstreamBuild} "fsmci"
    fi
    mustExistFile ${file}

    local md5sum=$(md5sum ${file} | cut -c1-32)
    mustHaveValue "${md5sum}" "md5sum of fingerprint file"

    echo ${md5sum}

    return
}
    
getTestJobNameFromFingerprint() {
    _getJobInformationFromFingerprint '_Test:' 1
}
getTestBuildNumberFromFingerprint() {
    _getJobInformationFromFingerprint '_Test:' 2
}
getBuildJobNameFromFingerprint() {
    _getJobInformationFromFingerprint '_Build:' 1
}
getBuildBuildNumberFromFingerprint() {
    _getJobInformationFromFingerprint '_Build:' 2
}
getPackageJobNameFromFingerprint() {
    _getPackageInformationFromFingerprint '_Package_-_package:' 1
}
getPackageBuildNumberFromFingerprint() {
    _getJobInformationFromFingerprint '_Package_-_package:' 2
}

_getJobInformationFromFingerprint() {
    requiredParameters LFS_CI_ROOT

    local jobNamePart=${1}
    mustHaveValue "${jobNamePart}" "job name part"

    local fieldNumber=${2}
    mustHaveValue "${fieldNumber}" "field number (1 / 2)"

    local md5sum=${3}
    if [[ -z ${md5sum} ]] ; then
        md5sum=$(getFingerprintOfCurrentJob)
    fi
    mustHaveValue "${md5sum}" "md5sum fingerprint"

    local xmlFile=$(createTempFile)
    local dataFile=$(createTempFile)
    _getProjectDataFromFingerprint ${md5sum} ${xmlFile}
    execute -n ${LFS_CI_ROOT}/bin/getFingerprintData ${xmlFile} > ${dataFile}

    local resultValue=$(grep -e ${jobNamePart} ${dataFile} | cut -d":" -f${fieldNumber} | sort -n | tail -n 1)
    mustHaveValue "${resultValue}" "requested info"

    echo ${resultValue}
    return
}

_getProjectDataFromFingerprint() {
    local md5sum=${1}
    mustHaveValue "${md5sum}" "md5sum / finger print"

    local file=${2}
    mustHaveValue "${file}" "file"

    local firstByte=$( cut -c1,2  <<< ${md5sum})
    local secondByte=$(cut -c3,4  <<< ${md5sum})
    local restBytes=$( cut -c5-32 <<< ${md5sum})

    local fingerprintFile=$(getConfig jenkinsRoot)/home/fingerprints/${firstByte}/${secondByte}/${restBytes}.xml

    runOnMaster "[[ -e ${fingerprintFile} ]] && cat ${fingerprintFile}" > ${file}

    if [[ -e ${file} && ! -s ${file} ]] ; then
        fatal "can not get fingerprint information from ${md5sum} / ${fingerprintFile}"
    fi

    return
}



