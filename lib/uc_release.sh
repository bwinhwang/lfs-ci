#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh
source ${LFS_CI_ROOT}/lib/subversion.sh

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @param   <none>
#  @return  <none>
ci_job_release() {

    requiredParameters TESTED_BUILD_JOBNAME TESTED_BUILD_NUMBER

    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    local branch=$(getBranchName)
    mustHaveBranchName

    local upstreamsFile=$(createTempFile)

    info "promoted build is ${TESTED_BUILD_JOBNAME} / ${TESTED_BUILD_NUMBER}"

    # find the related jobs of the build
    runOnMaster ${LFS_CI_ROOT}/bin/getUpStreamProject \
                    -j ${TESTED_BUILD_JOBNAME}        \
                    -b ${TESTED_BUILD_NUMBER}         \
                    -h ${jenkinsMasterServerPath} > ${upstreamsFile}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    if ! grep -q Package ${upstreamsFile} ; then
        error "cannot find upstream Package job"
        exit 1
    fi
    if ! grep -q Build   ${upstreamsFile} ; then
        error "cannot find upstream Build build"
        exit 1
    fi

    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local packageJobName=$(    grep Package ${upstreamsFile} | cut -d: -f1)
    local buildBuildNumber=$(  grep Build   ${upstreamsFile} | cut -d: -f2)
    local buildJobName=$(      grep Build   ${upstreamsFile} | cut -d: -f1)
    mustHaveValue ${packageJobName}
    mustHaveValue ${packageBuildNumber}
    mustHaveValue ${buildJobName}
    mustHaveValue ${buildBuildNumber}

    info "found package job: ${packageJobName} / ${packageBuildNumber}"
    info "found build   job: ${buildJobName} / ${buildBuildNumber}"
    
    local workspace=${lfsCiBuildsShare}/${branch}/build_${packageBuildNumber}
    if [[ ! -d ${workspace} ]] ; then
        error "can not find workspace of package job on build share (${workspace})"
        exit 1
    fi

    debug "found results of package job on share: ${workspace}"

    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    info "subJob is ${subJob}"
    case ${subJob} in
        upload_to_subversion)
            # from subversion.sh
            uploadToSubversion "${workspace}" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"
        ;;
        build_results_to_share)
            extractArtifactsOnReleaseShare "${buildJobName}" "${buildBuildNumber}"
        ;;
        build_results_to_share_on_site)
            copyToReleaseShareOnSite "${buildJobName}" "${buildBuildNumber}"
        ;;
        *)
            error "subJob not known (${subJob})"
            exit 1
        ;;
    esac

    return
}

## @fn      extractArtifactsOnReleaseShare( $jobName, $buildNumber )
#  @brief   extract the artifacts of build job on the local workspace and copy the artifacts to the
#           /build share.
#  @details structure on the share is
#           bld-<ss>-<cfg>/<label>/results/...
#  @param   {jobName}      name of the job
#  @param   {buildNumber}  number of the build
#  @return  <none>
extractArtifactsOnReleaseShare() {
    local jobName=$1
    local buildNumber=$2
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local labelName=$(getNextReleaseLabel)
    mustHaveValue "${labelName}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"

    cd ${workspace}/bld/
    for dir in bld-*-* ; do
        [[ -d ${dir} ]] || continue
        basename=$(basename ${dir})

        local destination=${lfsCiBuildsShare}/buildresults/${basename}/${labelName}
        info "copy ${basename} to buildresults share ${destination}"

        executeOnMaster mkdir -p ${destination}
        execute rsync -av --exclude=.svn ${workspace}/bld/${basename}/. ${jenkinsMasterServerHostName}:${destination}
    done

    info "clean up workspace"
    execute rm -rf ${workspace}/bld

    return
}

## @fn      copyToReleaseShareOnSite()
#  @brief   copy the released version from the build share to the other sites
#  @details «full description»
#  @todo    more doc
#  @param   <none>
#  @return  <none>
copyToReleaseShareOnSite() {

    requiredParameters SITE_NAME RELEASE_NAME

    local siteName=${SITE_NAME}
    local labelName=${RELEASE_NAME}

    for subsystemDirectory in $(find ${lfsCiBuildsShare}/buildresults/ -maxdepth 2 -name ${labelName} ) ; do
        [[ -d ${subsystemDirectory} ]] || continue

        local sourceDirectory=${lfsCiBuildsShare}/buildresults/${subsystemDirectory}
        info "copy ${sourceDirectory} to ${siteName}"

        # TODO: demx2fk3 2014-05-05 not fully implemented

    done

    return
}

## @fn      updateEnvironmentControlList( workspace )
#  @brief   update the ECL file 
#  @details «full description»
#  @todo    add more doc
#  @param   <none>
#  @return  <none>
updateEnvironmentControlList() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local eclUrl=$(getConfig eclUrl)
    mustHaveValue ${eclUrl}

    # TODO: demx2fk3 2014-04-30 fixme
    local eclKeysToUpdate=$(getConfig asdf)
    mustHaveValue "${eclKeysToUpdate}"

    info "checkout ECL from ${eclUrl}"
    svnCheckout ${eclUrl} ${workspace}
    mustHaveWritableFile ${workspace}/ECL

    for eclKey in ${eclKeysToUpdate} ; do

        local eclValue=$(getEclValue ${eclKey})
        mustHaveValue "${eclKey}"

        info "update ecl key ${eclKey} with value ${eclValue}"
        execute perl -pi -e "s:^${eclKey}=.*:${eclValue}=${value}:" ECL

    done

    svnDiff ${workspace}/ECL

    # TODO: demx2fk3 2014-05-05 not fully implemented

    return
}

## @fn      getEclValue(  )
#  @brief   get the Value for the ECL for a specified key
#  @todo    implement this
#  @param   {eclKey}    name of the key from ECL
#  @return  value for the ecl key
getEclValue() {
    local eclKey=$1

    # TODO: demx2fk3 2014-04-30 implement this

    echo ${eclKey}_${BUILD_NUMBER}
    return
}

