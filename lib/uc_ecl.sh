#!/bin/bash
## @file  uc_ecl.sh
#  @brief usecase update ECL with a new LFS production

[[ -z ${LFS_CI_SOURCE_artifacts}   ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion}  ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_jenkins}     ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_fingerprint} ]] && source ${LFS_CI_ROOT}/lib/fingerprint.sh

## @fn      ci_job_ecl()
#  @brief   update the ECL file 
#  @param   <none>
#  @return  <none>
ci_job_ecl() {
    usecase_LFS_UPDATE_ECL
    info "usecase LFS_UPDATE_ECL (legacy) done"
    return
}

## @fn      usecase_LFS_UPDATE_ECL()
#  @brief   update the ECL file 
#  @param   <none>
#  @return  <none>
usecase_LFS_UPDATE_ECL() {

    mustHavePreparedWorkspace

    local eclUrls=$(getConfig LFS_CI_uc_update_ecl_url)
    mustHaveValue "${eclUrls}"

    local buildJobName=$(getBuildJobNameFromFingerprint)
    mustHaveValue "${buildJobName}"     "build JobName"

    local buildBuildNumber=$(getBuildBuildNumberFromFingerprint)
    mustHaveValue "${buildBuildNumber}" "build BuildNumber"

    copyArtifactsToWorkspace ${buildJobName} ${buildBuildNumber} "externalComponents"

    for eclUrl in ${eclUrls} ; do
        info "updating ECL ${eclUrl}"
        updateAndCommitEcl ${eclUrl}
    done

    createArtifactArchive

    return
}


## @fn      mustHavePreparedWorkspace()
#  @brief   prepare the workspace with required artifacts and other stuff
#  @param   {upstreamProject}    name of the upstream project
#  @param   {upstreamBuild}      build number of the upstream project
#  @todo    TODO: demx2fk3 2015-06-08 move into a different file (maybe common.sh)
#  @return  <none>
mustHavePreparedWorkspace() {

    requiredParameters JOB_NAME BUILD_NUMBER

    local upstreamProject=${1}
    local upstreamBuild=${2}

    if [[ -z ${upstreamProject} ]] ; then
        requiredParameters UPSTREAM_PROJECT
        upstreamProject=${UPSTREAM_PROJECT}
    fi
    if [[ -z ${upstreamBuild} ]] ; then
        requiredParameters UPSTREAM_BUILD
        upstreamBuild=${UPSTREAM_BUILD}
    fi

    mustHaveValue "${upstreamProject}" "upstream project"
    mustHaveValue "${upstreamBuild}"   "upstream build"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    local requiredArtifacts=$(getConfig LFS_CI_prepare_workspace_required_artifacts)
    copyArtifactsToWorkspace "${upstreamProject}" "${upstreamBuild}" "${requiredArtifacts}"

    mustHaveNextLabelName
    local labelName=$(getNextReleaseLabel)

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${labelName}

    return
}

## @fn      getEclValue()
#  @brief   get the Value for the ECL for a specified key
#  @todo    implement this
#  @param   {eclKey}    name of the key from ECL
#  @return  value for the ecl key
getEclValue() {
    local eclKey=$1
    local oldValue=$2
    local newValue=

    debug "getting new ecl value for ${eclKey} / ${oldValue}"
    local workspace=$(getWorkspaceName)

    case ${eclKey} in
        ECL_PS_LFS_REL|ECL_PS_LRC_LCP_LFS_REL)
            mustHaveNextCiLabelName
            newValue=$(getNextCiLabelName | sed "s/PS_LFS_OS_/PS_LFS_REL_/")
        ;;
        ECL_PS_LFS_OS|ECL_PS_LRC_LCP_LFS_OS)
            mustHaveNextCiLabelName
            newValue=$(getNextCiLabelName)
        ;;
        ECL_PS_LFS_SDK3) 
            local commonentsFile=${workspace}/bld//bld-externalComponents-summary/externalComponents 
            mustExistFile ${commonentsFile}
            newValue=$(getConfig sdk3 -f ${commonentsFile})
        ;;
        ECL_PS_LFS_INTERFACE_REV)
            newValue=$((oldValue + 1))
        ;;
        *)
            newValue="unsupported_key_${eclKey}"
            fatal "unknown ECL key ${eclKey}"
        ;;
    esac

    debug "new value is ${newValue}"
    echo ${newValue}
    return
}


## @fn      updateAndCommitEcl(  )
#  @brief   update the ECL file with the given value and commit it
#  @param   {eclUrl}    url of the ECL (without filename)
#  @return  <none>
updateAndCommitEcl() {
    local eclUrl=$1
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local eclWorkspace=${workspace}/ecl_checkout
    execute rm -rfv ${eclWorkspace}

    info "checkout ECL from ${eclUrl} to ${eclWorkspace}"
    svnCheckout ${eclUrl} ${eclWorkspace}
    mustHaveWritableFile ${eclWorkspace}/ECL

    local eclKeysToUpdate=$(getConfig LFS_CI_uc_update_ecl_key_names)
    mustHaveValue "${eclKeysToUpdate}" "ECL Keys to update"

    for eclKey in ${eclKeysToUpdate} ; do
        local oldEclValue=$(grep "^${eclKey}=" ${eclWorkspace}/ECL | cut -d= -f2)
        local eclValue=$(getEclValue "${eclKey}" "${oldEclValue}")
        debug "got new value for eclKey ${eclKey} / oldValue ${oldEclValue}"

        mustHaveValue "${eclKey}"   "no key ${eclKey}"
        mustHaveValue "${eclValue}" "no value for ${eclKey}"

        info "update ecl key ${eclKey} with value ${eclValue} (old: ${oldEclValue})"
        execute perl -pi -e "s:^${eclKey}=.*:${eclKey}=${eclValue}:" ${eclWorkspace}/ECL
    done

    svnDiff ${eclWorkspace}/ECL

    local canCommit=$(getConfig LFS_CI_uc_update_ecl_can_commit_ecl)
    if [[ ${canCommit} ]] ; then
        local logMessage=${workspace}/ecl_commit_message
        echo "updating ECL" > ${logMessage} 
        svnCommit -F ${logMessage} ${eclWorkspace}/ECL
    else 
        warning "svn commit of ECL is disabled via configuration"
    fi
    return
}
