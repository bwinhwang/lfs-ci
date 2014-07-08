#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh

## @fn      ci_job_ecl()
#  @brief   update the ECL file 
#  @details �full description�
#  @todo    add more doc
#  @param   <none>
#  @return  <none>
ci_job_ecl() {
    requiredParameters JOB_NAME BUILD_NUMBER UPSTREAM_PROJECT UPSTREAM_BUILD

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    local eclUrl=$(getConfig LFS_CI_uc_update_ecl_url)
    mustHaveValue ${eclUrl}

    local eclKeysToUpdate=$(getConfig LFS_CI_uc_update_ecl_key_names)
    mustHaveValue "${eclKeysToUpdate}"

    local serverPath=$(getConfig jenkinsMasterServerPath)

    # find the related jobs of the build
    local upstreamsFile=$(createTempFile)
    runOnMaster ${LFS_CI_ROOT}/bin/getUpStreamProject \
                    -j ${UPSTREAM_PROJECT}        \
                    -b ${UPSTREAM_BUILD}         \
                    -h ${serverPath} > ${upstreamsFile}

    local packageJobName=$(    grep Package ${upstreamsFile} | cut -d: -f1)
    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local buildJobName=$(      grep Build   ${upstreamsFile} | cut -d: -f1)
    local buildBuildNumber=$(  grep Build   ${upstreamsFile} | cut -d: -f2)
    if [[ -z ${buildJobName} ]] ; then
        error "not trigger an ECL update without a build job name"
        exit 1
    fi

    info "upstream    is ${UPSTREAM_PROJECT} / ${UPSTREAM_BUILD}"
    info "build job   is ${buildJobName} / ${buildBuildNumber}"
    info "package job is ${packageJobName} / ${packageBuildNumber}"

    local requiredArtifacts=$(getConfig LFS_CI_UC_update_ecl_required_artifacts)
    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}" "${requiredArtifacts}"

    info "checkout ECL from ${eclUrl}"
    svnCheckout ${eclUrl} ${workspace}/ecl_checkout
    mustHaveWritableFile ${workspace}/ecl_checkout/ECL

    for eclKey in ${eclKeysToUpdate} ; do
        local oldEclValue=$(grep "^${eclKey}=" ${workspace}/ecl_checkout/ECL | cut -d= -f2)
        local eclValue=$(getEclValue "${eclKey}" "${oldEclValue}")
        debug "got new value for eclKey ${eclKey} / oldValue ${oldEclValue}"

        mustHaveValue "${eclKey}" "no key ${eclKey}"
        mustHaveValue "${eclValue}" "no value for ${eclKey}"

        info "update ecl key ${eclKey} with value ${eclValue} (old: ${oldEclValue})"
        execute perl -pi -e "s:^${eclKey}=.*:${eclKey}=${eclValue}:" ${workspace}/ecl_checkout/ECL

    done

    svnDiff ${workspace}/ecl_checkout/ECL

    local canCommit=$(getConfig LFS_CI_uc_update_ecl_can_commit_ecl)
    if [[ $canCommit ]] ; then
        svnCommit -m updating_ecl ${workspace}/ecl_checkout/ECL
    fi

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
        ECL_PS_LFS_REL)  
            mustHaveNextCiLabelName
            newValue=$(getNextCiLabelName | sed "s/PS_LFS_OS_/PS_LFS_REL_/")
        ;;
        ECL_PS_LFS_OS)   
            mustHaveNextCiLabelName
            newValue=$(getNextCiLabelName)
        ;;
        ECL_PS_LFS_SDK3) 
            local commonentsFile=${workspace}/bld//bld-externalComponents-summary/externalComponents 
            mustExistFile ${commonentsFile}
            newValue=$(getConfig sdk3 ${commonentsFile})
        ;;
        ECL_LFS)
            local branchNameInSubversion=$(getConfig SVN_lfs_branch_name)
            local rev=$(cut -d" " -f 3 ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt| sort -u | tail -n 1
)
            newValue=$(printf "%s@%d" "${branchNameInSubversion}" ${rev})
        ;;
        ECL_PS_LFS_INTERFACE_REV)
            newValue=$((oldValue + 1))
        ;;
        *)
            newValue="unsupported_key_${eclKey}"
        ;;
    esac

    debug "new value is ${newValue}"
    echo ${newValue}
    return
}


