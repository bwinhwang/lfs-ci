#!/bin/bash

## @@file fingerprint.sh
#  @brief handle the fingerprints from jenkins

LFS_CI_SOURCE_fingerprint='$Id$'

## @fn      getFingerprintOfCurrentJob()
#  @brief   get the fingerprint of the current running job
#  @param   <none>
#  @return  fingerprint of the current job
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
        copyAndExtractBuildArtifactsFromProject ${upstreamJob} ${upstreamBuild} "fsmci"
    fi
    mustExistFile ${file}

    local md5sum=$(md5sum ${file} | cut -c1-32)
    mustHaveValue "${md5sum}" "md5sum of fingerprint file"

    echo ${md5sum}

    return
}

## @fn      getFingerprintFromBuildName()
#  @brief   get the fingerprint of a given build name 
#  @param   {buildName} name of a build
#  @return  fingerprint of the current build name
getFingerprintFromBuildName() {
    local buildName=${1}
    mustHaveValue "${buildName}" "build name"

    md5sum=$(echo ${buildName} | md5sum | cut -c1-32)
    debug "getFingerprintFromBuildName: fingerprint of ${buildName} = ${md5sum}"
    mustHaveValue "${md5sum}" "md5sum of fingerprint file"

    echo ${md5sum}

    return
} 

## @fn      getTestJobNameFromFingerprint()
#  @brief   get name of the test job from the fingerprint (current job)
#  @param   {buildName}	optional
#  @return  name of the test job
getTestJobNameFromFingerprint() {
    _getJobInformationFromFingerprint '_Test:' 1 $1
}
   
## @fn      getTestBuildNumberFromFingerprint()
#  @brief   get build number of the test job from the fingerprint (current job)
#  @param   {buildName}	optional
#  @return  build number of the test job
getTestBuildNumberFromFingerprint() {
    _getJobInformationFromFingerprint '_Test:' 2 $1
}

## @fn      getBuildJobNameFromFingerprint()
#  @brief   get name of the build job from the fingerprint (current job)
#  @param   {buildName}	optional
#  @return  name of the build job
getBuildJobNameFromFingerprint() {
    _getJobInformationFromFingerprint '_Build:' 1 $1
}

## @fn      getBuildBuildNumberFromFingerprint()
#  @brief   get build number of the build job from the fingerprint (current job)
#  @param   {buildName}	optional
#  @return  build number of the build job
getBuildBuildNumberFromFingerprint() {
    _getJobInformationFromFingerprint '_Build:' 2 $1
}

## @fn      getPackageJobNameFromFingerprint()
#  @brief   get name of the package job from the fingerprint (current job)
#  @param   {buildName}	optional
#  @return  name of the package job
getPackageJobNameFromFingerprint() {
    _getJobInformationFromFingerprint '_Package_-_package:' 1 $1
}

## @fn      getPackageBuildNumberFromFingerprint()
#  @brief   get build number of the package job from the fingerprint (current job)
#  @param   {buildName}	optional
#  @return  build number of the package job
getPackageBuildNumberFromFingerprint() {
    _getJobInformationFromFingerprint '_Package_-_package:' 2 $1
}

## @fn      getJobBuildNumberFromFingerprint()
#  @brief   get build number of any job from the fingerprint (current job)
#  @param   {jobNamePart}	name of the jobname
#  @param   {buildName}	    optional
#  @return  build number of any job
getJobBuildNumberFromFingerprint() {
    _getJobInformationFromFingerprint $1 2 $2
}

## @fn      getJobJobNameFromFingerprint()
#  @brief   get job name of any job from the fingerprint (current job)
#  @param   {jobNamePart}	name of the jobname
#  @param   {buildName}	    optional
#  @return  job name of any job
getJobJobNameFromFingerprint() {
    _getJobInformationFromFingerprint $1 2 $2
}

## @fn      _getJobInformationFromFingerprint()
#  @brief   get job information of the fingerprint
#  @param   {jobNamePart}      name (regex) of the requested job (Build, Test, ...)
#  @param   {fieldNumber}      number of the file
#  @param   {buildName}        name of the build (This is an optional parameter. If set, the md5sum is calculated based on the build name and not based on the current job)

#  @return  result value from job (job name, build number)
_getJobInformationFromFingerprint() {
    requiredParameters LFS_CI_ROOT

    local jobNamePart=${1}
    mustHaveValue "${jobNamePart}" "job name part"

    local fieldNumber=${2}
    mustHaveValue "${fieldNumber}" "field number (1 / 2)"

    local buildName=${3}
    local md5sum=
    if [[ -z ${buildName} ]] ; then
        md5sum=$(getFingerprintOfCurrentJob)
    else
        md5sum=$(getFingerprintFromBuildName ${buildName})
    fi
    mustHaveValue "${md5sum}" "md5sum fingerprint"

    local xmlFile=$(createTempFile)
    local dataFile=$(createTempFile)
    _getProjectDataFromFingerprint ${md5sum} ${xmlFile}
    execute -n ${LFS_CI_ROOT}/bin/getFingerprintData ${xmlFile} > ${dataFile}

    debug "build information from fingerprint file"
    rawDebug ${dataFile}

    local resultValue=$(grep -e ${jobNamePart} ${dataFile} | cut -d":" -f${fieldNumber} | sort -n | tail -n 1)
    mustHaveValue "${resultValue}" "requested info"

    echo ${resultValue}
    return
}

## @fn      _getProjectDataFromFingerprint()
#  @brief   get the project data from the fingerprint
#  @param   {md5sum}    md5sum / fingerprint of the requested job
#  @param   {file}      fine name of the result file
#  @return  <none>
_getProjectDataFromFingerprint() {
    local md5sum=${1}
    mustHaveValue "${md5sum}" "md5sum / finger print"

    local file=${2}
    mustHaveValue "${file}" "file"
    local firstByte=$( cut -c1,2  <<< ${md5sum})
    local secondByte=$(cut -c3,4  <<< ${md5sum})
    local restBytes=$( cut -c5-32 <<< ${md5sum})

    local fingerprintFile=$(getConfig jenkinsHome)/fingerprints/${firstByte}/${secondByte}/${restBytes}.xml

    local server=$(getConfig jenkinsMasterServerHostName)
    mustHaveValue "${server}" "server name"
    execute -r 10 rsync --archive --rsh=ssh --verbose \
                        ${server}:${fingerprintFile}  \
                        ${file}
    if [[ -e ${file} && ! -s ${file} ]] ; then
        fatal "can not get fingerprint information from ${md5sum} / ${fingerprintFile}"
    fi

    return
}
