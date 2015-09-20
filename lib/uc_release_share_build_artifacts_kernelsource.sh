#!/bin/bash

[[ -z ${LFS_CI_SOURCE_release} ]] && source ${LFS_CI_ROOT}/lib/release.sh

## @fn      usecase_LFS_RELEASE_SHARE_BUILD_ARTIFACTS_KERNELSOURCES()
#  @brief   extract the artifacts (linux kernel sources only!!) of build job on the 
#           local workspace and copy the artifacts to the /build share.
#  @details structure on the share is
#           bld-<ss>-<cfg>/<label>/results/...
#  @param   {jobName}      name of the job
#  @param   {buildNumber}  number of the build
#  @return  <none>
usecase_LFS_RELEASE_SHARE_BUILD_ARTIFACTS_KERNELSOURCES() {
    mustBePreparedForReleaseTask

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME

    local jobName=$(getBuildJobNameFromFingerprint)
    mustHaveValue "${jobName}" "build - job name from fingerprint"

    local buildNumber=$(getBuildBuildNumberFromFingerprint)
    mustHaveValue "${buildNumber}" "build - build number from fingerprint"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    local buildName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${buildName}"

    local triggeredJobData=$(getDownStreamProjectsData ${jobName} ${buildNumber})
    mustHaveValue "${triggeredJobData}" "triggered job data"

    local jobData=
    for jobData in ${triggeredJobData} ; do
        local buildNumber=$(echo ${jobData} | cut -d: -f 1)
        local jobName=$(    echo ${jobData} | cut -d: -f 3-)
        local subTaskName=$(getSubTaskNameFromJobName ${jobName})

        info "checking for ${jobName} / ${buildNumber}"

        # TODO: demx2fk3 2014-10-14 this is wrong!!! it does not handle other branches correcly
        # BUT, the location of the kernel sources are the same on all branches
        case ${subTaskName} in
            FSM-r2) location=trunk      ;;
            FSM-r3) location=trunk      ;;
            FSM-r4) location=FSM_R4_DEV ;;
            LRC)    location=LRC        ;;
            FSM-r3-FSMDDALpdf) continue ;;
            *UT)               continue ;;
            *) fatal "subTaskName ${subTaskName} is not supported" ;;
        esac

        info "creating new workspace to copy kernel sources for ${jobName} / ${location}"
        createBasicWorkspace -l ${location} src-project
        copyArtifactsToWorkspace "${jobName}" "${buildNumber}" "kernelsources"

        local lastKernelLocation=$(build location bld/bld-kernelsources-linux)
        local destinationBaseDirectory=$(dirname ${lastKernelLocation})
        mustExistDirectory ${destinationBaseDirectory}

        local destination=${destinationBaseDirectory}/${labelName}

        [[ ! -d ${workspace}/bld/bld-kernelsources-linux ]] && continue
        [[   -d ${destination}                           ]] && continue

        info "copy kernelsources from ${jobName} to buildresults share ${destination}"

        if [[ ${canStoreArtifactsOnShare} ]] ; then
            # TODO: demx2fk3 2015-03-03 FIXME use execute -r 10 ssh master
            executeOnMaster chmod u+w $(dirname ${destination})
            executeOnMaster mkdir -p  ${destination}
            execute rsync -av --exclude=.svn ${workspace}/bld/bld-kernelsources-linux/. ${server}:${destination}/
            touch ${destination}
        else
            warning "storing artifacts on share is disabled in config"
        fi
    done

    # restore build name artifact for database events
    copyAndExtractBuildArtifactsFromProject "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "fsmci"

    return
}


