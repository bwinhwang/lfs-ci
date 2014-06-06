#!/bin/bash

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

# TODO: demx2fk3 2014-04-10 not working yet...

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue "${label}"

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"
    
    local branch=$(getBranchName)
    mustHaveBranchName

    local ciBuildShare=$(getConfig lfsCiBuildsShare)

    local localDirectory=${workspace}/upload
    # TODO: demx2fk3 2014-05-20 fixme. The os should be configurable
    local remoteDirectory=${ciBuildShare}/${productName}/${branch}/data/${label}/os

    # TODO: demx2fk3 2014-05-20 fixme use lastSuccessfull build here (or empty)
    local oldRemoteDirectory=${ciBuildShare}/${productName}/${branch}/data/$(ls ${ciBuildShare}/${productName}/${branch}/data/ | tail -n 1 )
    local hardlink=""

    info "copy build results to ${remoteDirectory}"
    info "based on ${oldRemoteDirectory}"

    execute mkdir -p ${remoteDirectory}

    if [[ -d ${oldRemoteDirectory} ]] ; then
        hardlink="--link-dest=${oldRemoteDirectory}/os/"
    fi
    execute rsync -av --delete ${hardlink} ${localDirectory}/. ${remoteDirectory}

    # TODO: demx2fk3 2014-04-10 link sdks
    executeOnMaster ln -sf ${ciBuildShare}/${productName}/${branch}/data/${label} ${ciBuildShare}/${productName}/${branch}/${label}
    executeOnMaster ln -sf ${ciBuildShare}/${productName}/${branch}/data/${label} ${ciBuildShare}/${productName}/${branch}/build_${BUILD_NUMBER}

    return
}
