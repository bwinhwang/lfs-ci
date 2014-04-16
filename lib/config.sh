#!/bin/bash

# this is the static configuration, which is valid for all scripting
# stuff in here.
# it must be also valid for all slaves and the master

# location of the java binary, used for jenkins start and jenkins cli
java=/usr/lib/jvm/jre-1.6.0-openjdk.x86_64/bin/java

# version number of jenkins, which should be used
jenkinsVersion=1.532.3

# location of the jenkins war files
jenkinsWarFile=${LFS_CI_ROOT}/lib/java/jenkins/jenkins-${jenkinsVersion}.war

# location of the jenkins installation on the master server
jenkinsRoot=/var/fpwork/${USER}/lfs-jenkins

# location of the ssl certificate and the private key for https of jenkins webinterface
jenkinsMasterSslCertificate=${LFS_CI_ROOT}/etc/lfs-ci.emea.nsn-net.net.crt
jenkinsMasterSslPrivateKey=${LFS_CI_ROOT}/etc/lfs-ci.emea.nsn-net.net.key

# hostname (fqdn) of the jenkins master server
jenkinsMasterServerHostName=maxi.emea.nsn-net.net

# http port of the jenkins master webinterface
jenkinsMasterServerHttpPort=1280

# https port of the jenkins master webinterface
jenkinsMasterServerHttpsPort=12443

# the http (unsecure) url of the jenkins master webinterface
jenkinsMasterServerHttpUrl=http://${jenkinsMasterServerHostName}:${jenkinsMasterServerHttpPort}/

# the https (secure) url of the jenkins master webinterface
jenkinsMasterServerHttpsUrl=http://${jenkinsMasterServerHostName}:${jenkinsMasterServerHttpsPort}/

# home directory of the jenkins master server installation
# (only valid on the master server)
jenkinsMasterServerPath=${jenkinsRoot}/home/

# location of the jenkins cli jar file
jenkinsCli=${LFS_CI_ROOT}/lib/java/jenkins/jenkins-cli-${jenkinsVersion}.jar

# path to the share, where the build artifacts are located
# (location for ulm, not valid for other sites)
artifactesShare=/build/home/${USER}/lfs/

# hostname of the svn master server
svnMasterServerHostName=svne1.access.nokiasiemensnetworks.com

# hostname of the svn slave server in Ulm
svnSlaveServerUlmHostName=ulscmi.inside.nsn.com

# url of the LFS source repositroy
lfsSourceRepos=https://${svnSlaveServerUlmHostName}/isource/svnroot/BTS_SC_LFS/

# url of the trunk version of LFS source
lfsSourceReposTrunk=${lfsSourceRepos}/os/trunk/

# location where the LFS delivery / productions / releases are put on (in Ulm only)
lfsDeliveryShare=/build/home/${USER}/delivery

# location on the share, where the ci results should be put on
lfsCiBuildsShare=/build/home/${USER}/ci_builds

# a hostname of a (random) linsee server in Ulm
linseeUlmServer=ulling04.emea.nsn-net.net

# ....
declare -A sitesBuildShareMap=(  ["Ulm"]="ulling01:/build/home/${USER}/lfs/"                  \
                                ["Oulu"]="ouling04.emea.nsn-net.net:/build/home/${USER}/lfs/" \
)
# ....
declare -A platformMap=(         ["fct"]="fsm3_octeon2" \
                           ["qemu_i386"]="qemu"         \
                         ["qemu_x86_64"]="qemu_64"      \
                                ["fspc"]="fspc"         \
                                ["fcmd"]="fcmd"         \
                                 ["arm"]="fsm35_k2"     \
)
# ...
declare -A archMap=(         ["fct"]="mips64-octeon2-linux-gnu" \
                       ["qemu_i386"]="i686-pc-linux-gnu"        \
                     ["qemu_x86_64"]="x86_64-pc-linux-gnu"      \
                            ["fspc"]="powerpc-e500-linux-gnu"   \
                            ["fcmd"]="powerpc-e500-linux-gnu"   \
)

## @fn      getConfig( key )
#  @brief   get the configuration to the requested key
#  @details �full description�
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


