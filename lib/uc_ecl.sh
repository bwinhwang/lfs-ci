#!/bin/bash
## @file  uc_ecl.sh
#  @brief usecase update ECL with a new LFS production

[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

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
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    # TODO: demx2fk3 2015-04-13 this is the big question: what will be
    # the upstream project / upstream build and where do we get the
    # information about the build.
    # maybe the fingerprint file is an solution here.
    info "upstream  is ${UPSTREAM_PROJECT} / ${UPSTREAM_BUILD}"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace


    # TODO: demx2fk3 2015-04-13 which artifacts do we require here
    local requiredArtifacts=$(getConfig LFS_CI_UC_update_ecl_required_artifacts)
    copyArtifactsToWorkspace "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "${requiredArtifacts}"

    mustHaveNextLabelName
    local labelName=$(getNextReleaseLabel)
    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${labelName}
    mustHavePermissionToRelease
    createReleaseLinkOnCiLfsShare ${labelName}

    local eclUrls=$(getConfig LFS_CI_uc_update_ecl_url)
    mustHaveValue "${eclUrls}"
    for eclUrl in ${eclUrls} ; do
        info "updating ECL ${eclUrl}"
        updateAndCommitEcl ${eclUrl}
    done

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
        ECL_LFS)
            local branchNameInSubversion=$(getConfig SVN_lfs_branch_name)
            local rev=$(cut -d" " -f 3 ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt| sort -un | tail -n 1 )
            mustHaveNextCiLabelName "${rev}" "revision"
            debug "branch ${branchNameInSubversion} rev ${rev}"
            newValue=$(printf "%s\@%d" "${branchNameInSubversion}" ${rev})
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

## @fn      mustHavePermissionToRelease()
#  @brief   checks, if the release can be released 
#  @details it was agreed with PS SCM, that LFS will not promote every release
#           to the ECL stack to not spam CCS and PS with new LFS releases
#           every 20-30 minutes.
#           So we can configure, if a release candidate gets the permission to release.
#           This can be configured in LFS_CI_uc_update_ecl_update_promote_every_xth_release
#           In addition, a RC will be released if the last release was long time ago 
#           (see config LFS_CI_uc_ecl_maximum_time_between_two_releases)
#           If a RC will be not released, this ECL update job will be set to unstable
#  @todo    This method can be removed, if PS SCM can handle the amount of LFS releases.
#  @param   <none>
#  @return  <none>
mustHavePermissionToRelease() {

    # TODO: demx2fk3 2014-07-22 remove this, if PS SCM can handle the load of LFSes...
    local number=$(getConfig LFS_CI_uc_update_ecl_update_promote_every_xth_release)
    if [[ $(( BUILD_NUMBER % ${number} )) != 0 ]] ; then
        # as agreement with PS SCM, we are just promoting every 4th build.
        # otherwise, we will spam ECL
        # btw: 0 % 4 == 0 

        requiredParameters WORKSPACE JOB_NAME BUILD_NUMBER LFS_CI_ROOT

        # unix time stamp in milliseconds: 1422347953131
        copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} lastSuccessfulBuild build.xml
        local lastBuildDate=$(execute -n ${LFS_CI_ROOT}/bin/xpath -q -e "/build/startTime/node()" ${WORKSPACE}/build.xml)
        mustHaveValue "${lastBuildDate}" "last build date in ms"
        rm -rf ${WORKSPACE}/build.xml

        local currentDate=$(( $(date +%s) * 1000 ))
        mustHaveValue "${currentDate}" "current build date in ms"

        local maxDiff=$(getConfig LFS_CI_uc_ecl_maximum_time_between_two_releases)
        local diff=$(( ${currentDate} - ${lastBuildDate} ))

        if [[ ${diff} -lt ${maxDiff} ]] ; then
            warning "not promoting this build. ONLY EVERY ${number} build will be promoted"
            warning "timediff is too low: is ${diff}s must be ${maxDiff}s"
            setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${labelName}<br>not promoted"
            setBuildResultUnstable
            exit 0
        fi

        info "enforcing promotion of release. Last release is ${diff}s ago."
    fi

    return
}

createReleaseLinkOnCiLfsShare() {
    local labelName=$1
    local linkDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_link_location)
    local pathToLink=../../$(getConfig LFS_CI_UC_package_copy_to_share_path_name)/${labelName}
    local relTagName=${labelName//PS_LFS_OS_/PS_LFS_REL_}
    info "creating link in CI_LFS RCversion ${relTagName}"
    execute mkdir -p ${linkDirectory}
    execute cd ${linkDirectory}
    execute ln -sf ${pathToLink} ${relTagName}
    return
}

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
    mustHaveValue "${eclKeysToUpdate}"

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
    fi
    return
}
