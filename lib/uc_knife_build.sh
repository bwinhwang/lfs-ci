#!/bin/bash
## @file uc_knife_build.sh
#  @brief usecase for create a lfs knife build
#  @details  workflow
# * triggered via WFT 
# * runnins as a Jenkins project in LFS CI
#   - INPUT
#     - name of the requestor of the knife (username, email, real name)
#     - name of the branch in BTS_SC_LFS (opt)
#     - knife.zip (opt)
#     - knife request id (from WFT) (opt)
#     - base of the knife (baseline name)
#   job parameter
#     - KNIFE: knife.tar.gz
#     - BASED_ON: - LFS
#     - 
#   - OUTPUT
#     - location (path on build share), where the LFS production is stored
#     - upload to S3
#
# * create a workspace
#   - based on baseline name
#   - or on branch name from BTS_SC_LFS
#   - we can use the existing createWorkspace function, but we have to
#     fake the revision state file with the baseline name:
#     src-bos <url> <LABEL>
#     src-kernelsources <url> <LABEL>
#     ...
#
# Limitations
#  - only on branches, which are compartible with the new CI
#
# in Jenkins 
# * jobnames
#   - LFS_KNIFE_-_knife_-_Build
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fcmd
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fspc
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_qemu
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r3_-_fsm3_octeon2
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r3_-_qemu_64
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r4_-_fsm4_axm
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r4_-_fsm4_k2
#   - LFS_KNIFE_-_knife_-_Package_-_package
#
# build names
#  - PS_LFS_OS_2015_01_0001 => 15010001
#  - FB_PS_LFS_OS_2015_01_0001 => fb15010001
#  - KNIFE_<id>_PS_LFS_OS_2015_01_0001 => knife<id>15010001
#
# Brain storming
# * we want to use as much code as possible from usecases build and package
# * we should think about to have a own configuation for a knife, which is overwriting the default values
#   (change in Config)
# * workspaces are unique
#   - /var/fpwork/${USER}/lfs-knife-workspaces/knifes.<dateTime>.<requestor>.<knifeId>
# * knife workspaces can be deleted after building (no matter if it is successful or not)

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion}      ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_special_build}   ]] && source ${LFS_CI_ROOT}/lib/special_build.sh
[[ -z ${LFS_CI_SOURCE_uc_lfs_package}  ]] && source ${LFS_CI_ROOT}/lib/uc_lfs_package.sh
[[ -z ${LFS_CI_SOURCE_jenkins}         ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh


## @fn      usecase_LFS_KNIFE_BUILD()
#  @brief   run the usecase LFS Knife Build
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_BUILD() {
    requiredParameters KNIFE_LFS_BASELINE REQUESTOR_USERID

    echo $KNIFE_LFS_BASELINE $REQUESTOR_USERID

    # get the information from WFT (opt)
    # get the information from jenkins

    local currentDateTime=$(date +%Y%m%d-%H%M%S)
    local label=$(printf "KNIFE_%s.%s" ${KNIFE_LFS_BASELINE} ${currentDateTime})
    local baseLabel=${KNIFE_LFS_BASELINE/_PS_LFS_REL_/_PS_LFS_OS_}

    local svnReposUrl=$(getConfig LFS_PROD_svn_delivery_os_repos_url -t tagName:${baseLabel} )
    mustExistInSubversion ${svnReposUrl}/tags/${baseLabel}/doc/scripts/ revisions.txt
    local revision=$(svnCat ${svnReposUrl}/tags/${baseLabel}/doc/scripts/revisions.txt | cut -d" " -f3 | sort -nu | tail -n 1)

    local location=$(getConfig LFS_PROD_tag_to_branch -t tagName:${baseLabel})
    mustHaveValue "${location}" "location from base label"

    export LFS_CI_GLOBAL_BRANCH_NAME=${location}

    info "using revision ${location}@${revision} instead of ${KNIFE_LFS_BASELINE}"

    # in knife usecase, there are no options to select the platform from the user
    # side. So we are setting them up for them.
    export LFS_BUILD_FSMR2=true
    export LFS_BUILD_FSMR3=true
    export LFS_BUILD_FSMR4=true
    export LFS_BUILD_LRC=true

    specialBuildPreparation KNIFE ${label} ${revision} ${location}

    return
}

## @fn      usecase_LFS_KNIFE_BUILD_PLATFORM()
#  @brief   build a lfs knife
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_BUILD_PLATFORM() {
    specialBuildCreateWorkspaceAndBuild KNIFE

    info "build job finished."
    return
}

## @fn      usecase_LFS_KNIFE_PACKAGE()
#  @brief   run the usecase lfs knife package
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_PACKAGE() {
    requiredParameters LFS_CI_ROOT WORKSPACE

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustHaveLocationForSpecialBuild
    info "running usecase LFS package"
    ci_job_package

    specialBuildUploadAndNotifyUser KNIFE

    info "knife is done."
    return
}

## @fn     usecase_LFS_KNIFE_WFT_TRIGGER()
#  @brief  interface from/to WFT for LFS knifing
#  @param  <none>
#  @param  <none>
usecase_LFS_KNIFE_WFT_TRIGGER() {
    local zipFile="knife.zip"
    local knifeId=${KNIFE_ID}
    local xmlFile=${WORKSPACE}/knife_${knifeId}.xml
    local wftHostAddress=$(getConfig WORKFLOWTOOL_hostname)
    local wftApiKey=$(getConfig WORKFLOWTOOL_api_key)

    mustHaveValue "${knifeId}" "knifeId"
    mustHaveValue "${wftHostAddress}" "wftHostAddress"
    mustHaveValue "${wftApiKey}" "wftApiKey"
    mustHaveValue "${WORKSPACE}" "WORKSPACE"

    info "knifeId: ${knifeId}"

    # Get XML from WFT
    curl -k ${wftHostAddress}/ext/knife/${knifeId}/info -o ${xmlFile}

    # Get info from XML and set build description
    local ftpPath=$(${LFS_CI_ROOT}/bin/xpath -e "/knife/dir/text()" ${xmlFile})
    local requestor=$(${LFS_CI_ROOT}/bin/xpath -e "/knife/requestor/text()" ${xmlFile})
    local lfsBaseline=$(${LFS_CI_ROOT}/bin/xpath -e "/knife/baseline/text()" ${xmlFile})
    mustHaveValue "${ftpPath}" "ftpPath"
    mustHaveValue "${requestor}" "requestor"
    mustHaveValue "${lfsBaseline}" "lfsBaseline"
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "knife-id: ${knifeId}, requestor: ${requestor}, lfs-baseline: ${lfsBaseline}"

    # wft api: set knife build as started
    curl -k ${wftHostAddress}/ext/knife/${knifeId}/started?access_key=${wftApiKey}

    source ${LFS_CI_ROOT}/lib/autoftp.sh
    ftpPath=$(echo ${ftpPath} | cut -d'\' -f5- | sed -e 's,\\,/,')
    ftpGet ${ftpPath} ${zipFile}
    mustExistsFile ${zipFile}
    mv ${zipFile} ${WORKSPACE}
    unzip ${WORKSPACE}/${zipFile}

    # trigger lfs knife build job with required parameters
    mustHaveValue "${KNIFE_BUILD_JOB}" "KNIFE_BUILD_JOB"
    local jenkinsCmdl=$(getConfig jenkinsCli)
    local jenkinsMasterAddress=$(getConfig jenkinsMasterServerHttpsUrl)
    info "Trigger jenkins job ${KNIFE_BUILD_JOB} and wait until it is finished."
    local jobResult=$(java -jar ${jenkinsCmdl} -s ${jenkinsMasterAddress} build ${KNIFE_BUILD_JOB} -p "lfs.patch=${WORKSPACE}/lfs.patch" -p "KNIFE_LFS_BASELINE=${lfsBaseline}" -s)

    local jobNumber=$(echo ${jobResult} | awk -F'#' '{print $1}' | sed -e 's/#//')
    local jobStatus=$(echo ${jobResult} | awk '{print $8}')

    if [[ "${jobStatus}" == "FAILURE" ]]; then
        curl -k ${wftHostAddress}/ext/knife/${knifeId}/failed?access_key=${wftApiKey}&result_url=${jenkinsMasterAddress}/job/${KNIFE_BUILD_JOB}/${jobNumber}
        error "KNIFE build job failed: ${jenkinsMasterAddress}/job/${KNIFE_BUILD_JOB}/${jobNumber}"
    elif [[ "${jobStatus}" == "SUCCESS" ]]; then
        curl -k ${wftHostAddress}/ext/knife/${knifeId}/succeeded?access_key=${wftApiKey}
        info "KNIFE build job succeeded: ${jenkinsMasterAddress}/job/${KNIFE_BUILD_JOB}/${jobNumber}"
    else
        jobStatus="FAILURE"
        error "Unkown status of Job ${KNIFE_BUILD_JOB}"
    fi

    # TODO
    # * wft api: push (location of the results of the knife) s3 url to wft  -> in den artifacts fom knife package job (readme file).
    ### Please note, that currently S3 URL can be stored starting with next WFT version (after 29th of june)

    # set build description depending on KNIFE_BUILD_JOB
    executeJenkinsCli set-build-result ${jobStatus}
}
