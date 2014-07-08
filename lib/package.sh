#!/bin/bash

LFS_CI_SOURCE_package='$Id$'

## @fn      getArchitectureFromDirectory( $dir )
#  @brief   get the arcitecture from the bld directory
#  @details maps e.g. fct to mips64-octeon2-linux-gnu
#           see also mapping on config.sh
#  @param   {directory}    a bld directory name
#  @return  architecture
getArchitectureFromDirectory() {
    local directory=$1
    baseName=$(basename ${directory})
    directoryPlatform=$(cut -d- -f3 <<< ${baseName})
    echo ${archMap["${directoryPlatform}"]}
    return
}

## @fn      getPlatformFromDirectory( $dir )
#  @brief   get the platform from the bld directory
#  @details maps e.g. fct to fsm3_octeon2
#           see also mapping in config.sh
#  @param   {directory}    a bld directory name
#  @return  platform
getPlatformFromDirectory() {
    local directory=$1
    baseName=$(basename ${directory})
    directoryPlatform=$(cut -d- -f3 <<< ${baseName})
    destinationsPlatform=${platformMap["${directoryPlatform}"]}
    echo ${destinationsPlatform}
    return
}

## @fn      mustHaveArchitectureFromDirectory( $dir, $arch )
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

## @fn      mustHavePlatformFromDirectory( $dir, $arch )
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
#  @details «full description»
#  @todo    «description of incomplete business»
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
    mustHaveValue "${label}"

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"
    
    local branch=$(getBranchName)
    mustHaveBranchName

    local remoteDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${label}
    local localDirectory=${workspace}/upload
    mustExistDirectory ${localDirectory}

    info "copy build results from ${localDirectory} to ${remoteDirectory}/os/"
    execute mkdir -p ${remoteDirectory}/os/
    execute rsync -av --delete ${hardlink} ${localDirectory}/. ${remoteDirectory}/os/
    execute cd ${remoteDirectory}

    # PS SCM - which are responsible for syncing this share to the world wants the group writable
    execute chmod -R g+w ${remoteDirectory}

    info "linking sdk"
    local commonentsFile=${workspace}/bld/bld-externalComponents-summary/externalComponents 
    mustExistFile ${commonentsFile}
    for sdk in $(getConfig LFS_CI_UC_package_linking_component) ; do
        local sdkValue=$(getConfig ${sdk} ${commonentsFile})
        mustExistDirectory ../../../SDKs/${sdkValue}
        execute ln -sf ../../../SDKs/${sdkValue} ${sdk}
    done

    local linkDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_link_location)
    local pathToLink=../../$(getConfig LFS_CI_UC_package_copy_to_share_path_name)/${label}
    # get the latest used revision in this build
    local revision=$(cut -d" " -f 3 ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt| sort -u | tail -n 1)
    mustHaveValue "${revision}" "latest used revision"

    info "create link in RCversion to "
    execute mkdir -p ${linkDirectory}
    execute cd ${linkDirectory}
    execute ln -sf ${pathToLink} ${label}
    execute ln -sf ${pathToLink} "trunk@${revision}"

    # this is only for internal use!
    info "creating link for internal usage"
    local internalLinkDirectory=$(getConfig LFS_CI_UC_package_internal_link)
    execute mkdir -p ${internalLinkDirectory}
    execute ln -sf ${remoteDirectory} ${internalLinkDirectory}/build_${BUILD_NUMBER}

    info "create link to artifacts"
    local artifactesShare=$(getConfig artifactesShare)
    local artifactsPathOnShare=${artifactesShare}/${JOB_NAME}/${BUILD_NUMBER}
    local artifactsPathOnMaster=$(getBuildDirectoryOnMaster)/archive
    executeOnMaster mkdir -p  ${artifactsPathOnShare}/save
    executeOnMaster ln    -sf ${remoteDirectory} ${artifactsPathOnMaster}

    return
}
