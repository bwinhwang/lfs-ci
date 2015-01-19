#!/bin/bash

LFS_CI_SOURCE_package='$Id$'

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh

## @fn      getArchitectureFromDirectory()
#  @brief   get the arcitecture from the bld directory
#  @details maps e.g. fct to mips64-octeon2-linux-gnu
#           see also mapping on config.sh
#  @param   {directory}    a bld directory name
#  @return  architecture
getArchitectureFromDirectory() {
    local directory=$1
    local baseName=$(basename ${directory})
    local directoryPlatform=$(cut -d- -f3 <<< ${baseName})
    echo ${archMap["${directoryPlatform}"]}
    return
}

## @fn      getPlatformFromDirectory()
#  @brief   get the platform from the bld directory
#  @details maps e.g. fct to fsm3_octeon2
#           see also mapping in config.sh
#  @param   {directory}    a bld directory name
#  @return  platform
getPlatformFromDirectory() {
    local directory=$1
    local baseName=$(basename ${directory})
    local directoryPlatform=$(cut -d- -f3 <<< ${baseName})
    local destinationsPlatform=${platformMap["${directoryPlatform}"]}
    echo ${destinationsPlatform}
    return
}

## @fn      mustHaveArchitectureFromDirectory()
#  @brief   ensure, that there is a architecture name
#  @param   {dir}             the bld directory name
#  @param   {architecture}    the architecture
#  @return  <none>
#  @return  1 if there is no archtecutre, 0 otherwise
mustHaveArchitectureFromDirectory() {
    local directory=$(basename $1)
    local architecture=$2
    if [[ ! ${architecture} ]] ; then
        error "can not found map for architecture ${directory}"
        exit 1
    fi
    return
}

## @fn      mustHavePlatformFromDirectory()
#  @brief   ensure, that there is a platform name
#  @param   {dir}             the bld directory name
#  @param   {architecture}    the platform
#  @return  <none>
#  @return  1 if there is no platform, 0 otherwise
mustHavePlatformFromDirectory() {
    local directory=$(basename $1)
    local platform=$2
    if [[ ! ${platform} ]] ; then
        error "can not found map for platform ${directory}"
        exit 1
    fi
    return
}

## @fn      copyReleaseCandidateToShare()
#  @brief   copy the release candidate to the build share
#  @param   <none>
#  @return  <none>
copyReleaseCandidateToShare() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local shouldCopyToShare=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)
    if [[ ! ${shouldCopyToShare} ]] ; then
        debug "will not copy this production to CI_LFS share"
        return
    fi

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue "${label}" "next label name"

    mustHavePreviousLabelName
    local oldLabel=${LFS_CI_PREV_CI_LABEL_NAME}
    mustHaveValue "${oldLabel}" "old label name"

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"
    
    local branch=$(getBranchName)
    mustHaveBranchName

    local remoteDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${label}
    local localDirectory=${workspace}/upload
    mustExistDirectory ${localDirectory}

    info "copy build results from ${localDirectory} to ${remoteDirectory}/os/"
    local hardlink=
    local basedOn=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${oldLabel}/os/

    if [[ -d ${basedOn} ]] ; then
        info "based on ${basedOn}"
        hardlink="--link-dest=${basedOn}"
    fi

    local rsyncOpts=$(getConfig RSYNC_options)

    # PS SCM - which are responsible for syncing this share to the world wants the group writable
    execute chmod -R g+w ${localDirectory}

    execute mkdir -p ${remoteDirectory}/os/
    execute rsync -av --delete ${hardlink} ${localDirectory}/ ${remoteDirectory}/os/
    execute cd ${remoteDirectory}

    info "linking sdk"
    local commonentsFile=${workspace}/bld/bld-externalComponents-summary/externalComponents 
    mustExistFile ${commonentsFile}
    for sdk in $(getConfig LFS_CI_UC_package_linking_component) ; do
        local sdkValue=$(getConfig ${sdk} ${commonentsFile})
        # TODO: demx2fk3 2014-08-26 hack place make this different
        if [[ ${sdk} = sdk3 && -z ${sdkValue} ]] ; then
            sdkValue=$(getConfig sdk ${commonentsFile})
        fi
        mustHaveSdkOnShare ${sdkValue}
        execute ln -sf ../../../SDKs/${sdkValue} ${sdk}
    done


    # this is only for internal use!
    info "creating link for internal usage"
    local internalLinkDirectory=$(getConfig LFS_CI_UC_package_internal_link)
    execute mkdir -p ${internalLinkDirectory}
    execute ln -sf ${remoteDirectory} ${internalLinkDirectory}/build_${BUILD_NUMBER}

    # TODO: demx2fk3 2014-07-15 FIXME : createSymlinksToArtifactsOnShare ${remoteDirectory}
    local artifactsPathOnMaster=$(getBuildDirectoryOnMaster)/archive
    executeOnMaster ln -sf ${remoteDirectory} ${artifactsPathOnMaster}

    # TODO: demx2fk3 2015-01-09 create also link to the build jobs

    return
}

## @fn      mustHaveSdkOnShare()
#  @brief   ensures, that the sdk baseline is on the CI_LFS/SDKs share
#  @param   {sdkBaseline}    name of the sdk baseline
#  @return  <none>
mustHaveSdkOnShare() {
    local sdkBaseline=$1
    mustHaveValue "${sdkBaseline}" "sdk baseline"

    local ciLfsLocation=$(getConfig LFS_CI_UC_package_copy_to_share_name)
    mustExistDirectory ${ciLfsLocation}
    mustExistDirectory ${ciLfsLocation}/SDKs

    [[ -d ${ciLfsLocation}/SDKs/${sdkBaseline} ]] && return

    local sdkSvnLocation=$(getConfig LFS_CI_UC_package_sdk_svn_location)

    svnExport {sdkSvnLocation}/tags/${sdkBaseline} ${ciLfsLocation}/SDKs/${sdkBaseline}
    
    return
}
