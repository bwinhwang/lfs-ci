#!/bin/bash

# this is the static configuration, which is valid for all scripting
# stuff in here.
# it must be also valid for all slaves and the master

# hostname (fqdn) of the jenkins master server
jenkinsMasterServerHostName=maxi.emea.nsn-net.net

# http port of the jenkins master webinterface
jenkinsMasterServerHttpPort=1280

# https port of the jenkins master webinterface
jenkinsMasterServerHttpsPort=12443

# the http (unsecure) url of the jenkins master webinterface
jenkinsMasterServerHttpUrl=http://${jenkinsMasterServerHostName}:${jenkinsMasterServerPort}/

# the https (secure) url of the jenkins master webinterface
jenkinsMasterServerHttpsUrl=http://${jenkinsMasterServerHostName}:${jenkinsMasterServerPort}/

# home directory of the jenkins master server installation
# (only valid on the master server)
jenkinsMasterServerPath=/var/fpwork/${USER}/lfs-jenkins/home/

# path to the share, where the build artifacts are located
# (location for ulm, not valid for other sites)
artifactesShare=/build/home/${USER}/lfs/

svnMasterServerHostName=svne1.access.nokiasiemensnetworks.com
svnSlaveServerUlmHostName=ulscmi.inside.nsn.com
lfsSourceRepos=https://${svnSlaveServerUlmHostName}/isource/svnroot/BTS_SC_LFS/
lfsSourceReposTrunk=${lfsSourceRepos}/os/trunk/

lfsDeliveryShare=/build/home/${USER}/delivery
lfsCiBuildsShare=/build/home/${USER}/ci_builds

declare -A sitesBuildShareMap=(  ["Ulm"]="ulling01:/build/home/${USER}/lfs/"                  \
                                ["Oulu"]="ouling04.emea.nsn-net.net:/build/home/${USER}/lfs/" \
                              )

    declare -A platformMap=(         ["fct"]="fsm3_octeon2" \
                               ["qemu_i386"]="qemu"         \
                             ["qemu_x86_64"]="qemu_64"      \
                                    ["fspc"]="fspc"         \
                                    ["fcmd"]="fcmd"         \
                                     ["arm"]="fsm35_k2"     \
                           )
    declare -A archMap=(         ["fct"]="mips64-octeon2-linux-gnu" \
                           ["qemu_i386"]="i686-pc-linux-gnu"        \
                         ["qemu_x86_64"]="x86_64-pc-linux-gnu"      \
                                ["fspc"]="powerpc-e500-linux-gnu"   \
                                ["fcmd"]="powerpc-e500-linux-gnu"   \
                          )

## @fn      getConfig( key )
#  @brief   get the configuration to the requested key
#  @details «full description»
#  @todo    move this into a generic module. make it also more configureable
#  @param   {key}    key name of the requested value
#  @return  value for the key
getConfig() {
    local key=$1

    trace "get config value for ${key}"

    taskName=$(getTaskNameFromJobName)
    subTaskName=$(getSubTaskNameFromJobName)
    location=$(getLocationName)
    config=$(getTargetBoardName)

    case "${key}" in
        subsystem)
            case "${subTaskName}" in
                FSM-r2       ) echo src-psl      ;;
                FSM-r2-rootfs) echo src-rfs      ;;
                FSM-r3)        echo src-fsmpsl   ;;
                FSM-r3.5)      echo src-fsmpsl35 ;;
                LRC)           echo src-lrcpsl   ;;
                UBOOT)         echo src-fsmbrm   ;;
            esac
        ;;
        locationMapping)
            case "${subTaskName}" in
                LRC)    echo LRC         ;;
                UBOOT)  echo nightly     ;;
                FSM-r3) echo ${location} ;;
            esac
        ;;
        additionalSourceDirectories)
            case "${subTaskName}" in
                LRC)    echo src-lrcbrm src-cvmxsources src-kernelsources src-bos src-lrcddg src-ifdd src-commonddal src-lrcddal src-tools src-rfs src-toolset ;;
            esac
        ;;
        *) : ;;
    esac
}


