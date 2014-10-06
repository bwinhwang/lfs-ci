#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

## @fn      ci_job_ecl()
#  @brief   update the ECL file 
#  @details 
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

    local packageJobName=$(    grep Package ${upstreamsFile} | cut -d: -f1 | sort -n | tail -n 1)
    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2 | sort -n | tail -n 1)
    local buildJobName=$(      grep Build   ${upstreamsFile} | cut -d: -f1 | sort -n | tail -n 1)
    local buildBuildNumber=$(  grep Build   ${upstreamsFile} | cut -d: -f2 | sort -n | tail -n 1)
    if [[ -z ${buildJobName} ]] ; then
        error "not trigger an ECL update without a build job name"
        setBuildResultUnstable
        exit 0
    fi

    info "upstream    is ${UPSTREAM_PROJECT} / ${UPSTREAM_BUILD}"
    info "build job   is ${buildJobName} / ${buildBuildNumber}"
    info "package job is ${packageJobName} / ${packageBuildNumber}"

    local requiredArtifacts=$(getConfig LFS_CI_UC_update_ecl_required_artifacts)
    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}" "${requiredArtifacts}"

    local ciBuildShare=$(getConfig LFS_CI_UC_package_internal_link)
    local releaseDirectory=${ciBuildShare}/build_${packageBuildNumber}
    mustExistSymlink ${releaseDirectory}

    local releaseDirectoryLinkDestination=$(readlink -f ${releaseDirectory})
    mustExistDirectory ${releaseDirectoryLinkDestination}

    mustHaveNextLabelName
    local labelName=$(getNextReleaseLabel)
    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${labelName}

    # TODO: demx2fk3 2014-07-22 remove this, if PS SCM can handle the load of LFSes...
    local number=$(getConfig LFS_CI_uc_update_ecl_update_promote_every_xth_release)
    if [[ $(( BUILD_NUMBER % ${number} )) != 0 ]] ; then
        # as agreement with PS SCM, we are just promoting every 4th build.
        # otherwise, we will spam ECL
        warning "not promoting this build. ONLY EVERY ${number} build will be promoted"
        setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${labelName}<br>not promoted"
        setBuildResultUnstable
        exit 0
    fi


    local linkDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_link_location)
    local pathToLink=../../$(getConfig LFS_CI_UC_package_copy_to_share_path_name)/${labelName}
    local relTagName=${labelName//PS_LFS_OS_/PS_LFS_REL_}
    info "creating link in CI_LFS RCversion ${relTagName}"
    execute mkdir -p ${linkDirectory}
    execute cd ${linkDirectory}
    execute ln -sf ${pathToLink} ${relTagName}
    # TODO: demx2fk3 2014-07-22 disabled, bis jemand schreit...
    # execute ln -sf ${pathToLink} "trunk@${revision}"

    # TODO: demx2fk3 2014-07-22 fixme hack - cleanup
    # TODO: demx2fk3 2014-07-23 is/was required for lfs2cloud by Rainer Schiele
#     local buildResultsShare=$(getConfig LFS_PROD_UC_ecl_update_buildresults_share)/${labelName}
#     execute mkdir -p ${buildResultsShare}/bld
#     cd ${buildResultsShare}/bld/
#     for key in $(cut -d" " -f 1 ${workspace}/bld/bld-externalComponents-summary ) ; do
#         value=$(getConfig ${key} -f ${workspace}/bld/bld-externalComponents-summary)
#         
#         case ${key} in
#             sdk*) execute ln -sf ../../../sdk/tags/${value} ${key} ;;
#             bld*) execute ln -sf ./../../releases/bld/${value} ${key} ;;
#             pkgpool) execute ln -sf ../../../pkgpool/${value} ${key} ;;
#             *) error "do not support ${key} / ${value} for ${buildResultsShare}" ; exit 1 ;;
#         esac
#     done
    # end of hack

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
        local logMessage=$(createTempFile)
        echo "updating ECL" > ${logMessage} 
        svnCommit -F ${logMessage} ${workspace}/ecl_checkout/ECL
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
            newValue=$(getConfig sdk3 ${commonentsFile})
        ;;
        ECL_LFS)
            local branchNameInSubversion=$(getConfig SVN_lfs_branch_name)
            local rev=$(cut -d" " -f 3 ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt| sort -u | tail -n 1 )
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


