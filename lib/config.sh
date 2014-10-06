#!/bin/bash

LFS_CI_SOURCE_config='$Id$'

# the following methods are parsing the jenkins job name and return the
# required / requested information. At the moment, the script will be called
# every time. This is normally not so fast as it should be.
# TODO: demx2fk3 2014-03-27 it should be done in this way:
#  * check, if there is a "property" file which includes the information
#  * if the files does not exist, create a new file with all information
#  * source the new created file
#  * use the sourced information
# this is caching the information

# the syntax of the jenkins job name is:
#
# LFS _ ( CI | PROD ) _-_ <branch> _-_ <task> _-_ <build> _-_ <boardName>
#

## @fn      getLocationName()
#  @brief   get the location name (aka branch) from the jenkins job name
#  @param   {jobName} name of the job, optional, default JOB_NAME
#  @return  location name
getLocationName() {
    requiredParameters JOB_NAME

    local jobName=${1:-${JOB_NAME}}
    local location=$(${LFS_CI_ROOT}/bin/getFromString.pl "${jobName}" location)

    # 2014-02-17 demx2fk3 TODO do this in a better wa
    case ${location} in
        fsmr4)    echo FSM_R4_DEV      ;;
        kernel3x) echo KERNEL_3.x_DEV  ;;
        trunk)    echo pronb-developer ;;
        *)        echo ${location}     ;;
    esac

    return
}

## @fn      getTaskNameFromJobName()
#  @brief   get the task name from the jenkins job name
#  @param   <none>
#  @return  task name
getTaskNameFromJobName() {
    ${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" taskName
    return
}

## @fn      getSubTaskNameFromJobName()
#  @brief   get the sub task name from the jenkins job name
#  @param   <none>
#  @return  sub task name
getSubTaskNameFromJobName() {
    ${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" subTaskName
    return
}

## @fn      getTargetBoardName()
#  @brief   get the target board name from the jenkins job name
#  @param   <none>
#  @return  target board name
getTargetBoardName() {
    ${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" platform
    return
}


getProductNameFromJobName() {
    ${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" productName
    return
}

## @fn      getConfig( key )
#  @brief   get the configuration to the requested key
#  @details «full description»
#  @todo    move this into a generic module. make it also more configureable
#  @param   {key}    key name of the requested value
#  @return  value for the key
getConfig() {
    local key=$1
    local file=$2

    local productName=$(getProductNameFromJobName)
    local taskName=$(getTaskNameFromJobName)
    local subTaskName=$(getSubTaskNameFromJobName)
    local location=$(getLocationName)
    local config=$(getTargetBoardName)

    # TODO: demx2fk3 2014-08-05 this should be always commented out, only required for debugging
    # echo 1>&2 "get config value for ${key} using ${file}"
    # echo 1>&2 "config/${config}"
    # echo 1>&2 "location/${location}"
    # echo 1>&2 "subTaskName/${subTaskName}"
    # echo 1>&2 "taskName/${taskName}"
    # echo 1>&2 "productName/${productName}"

    if [[ ! -e ${file} ]] ; then
        file=${LFS_CI_ROOT}/etc/file.cfg
    fi

    ${LFS_CI_ROOT}/bin/getConfig -k "${key}" -f ${file} \
        -t productName:${productName} \
        -t taskName:${taskName}       \
        -t location:${location}       \
        -t config:${config}          

    return
}


# this is the static configuration, which is valid for all scripting
# stuff in here.
# it must be also valid for all slaves and the master

# ....
declare -A platformMap=(         ["fct"]="fsm3_octeon2" \
                           ["qemu_i386"]="qemu"         \
                         ["qemu_x86_64"]="qemu_64"      \
                                ["fspc"]="fspc"         \
                                ["fcmd"]="fcmd"         \
                                 ["arm"]="fsm4_k2"      \
                           ["keystone2"]="fsm4_k2"      \
                                 ["axm"]="fsm4_axm"     \
                            ["fsm4_axm"]="fsm4_axm"     \
                             ["fsm4_k2"]="fsm4_k2"      \
                            ["fsm4_arm"]="fsm4_k2"      \
                                 ["arm"]="fsm4_k2"      \
                                ["lcpa"]="lrc-octeon2"  \
)

# ....
declare -A archMap=(         ["fct"]="mips64-octeon2-linux-gnu"      \
                            ["lcpa"]="mips64-octeon2-linux-gnu"      \
                       ["qemu_i386"]="i686-pc-linux-gnu"             \
                     ["qemu_x86_64"]="x86_64-pc-linux-gnu"           \
                            ["fspc"]="powerpc-e500-linux-gnu"        \
                            ["fcmd"]="powerpc-e500-linux-gnu"        \
                             ["axm"]="arm-cortexa15-linux-gnueabihf" \
                       ["keystone2"]="arm-cortexa15-linux-gnueabihf" \
                        ["fsm4_axm"]="arm-cortexa15-linux-gnueabihf" \
                        ["fsm4_arm"]="arm-cortexa15-linux-gnueabihf" \
                             ["arm"]="arm-cortexa15-linux-gnueabihf" \
                         ["fsm4_k2"]="arm-cortexa15-linux-gnueabihf" \
)

# maps the location name to the branch name in the svn delivery repos
declare -A locationToSubversionMap=( ["LFS_pronb-developer"]="PS_LFS_OS_MAINBRANCH" \
                                     ["LFS_FB1407"]="PS_LFS_OS_FB1407"              \
                                     ["LFS_FB1408"]="PS_LFS_OS_FB1408"              \
                                     ["LFS_FB1409"]="PS_LFS_OS_FB1409"              \
                                     ["LFS_FSM_R4_DEV"]="PS_LFS_OS_FSM_R4"          \
                                     ["LFS_LRC_FB1408"]="PS_LFS_OS_LRC_FB1408"      \
                                     ["LFS_LRC_FB1409"]="PS_LFS_OS_LRC_FB1409"      \
                                     ["LFS_LRC"]="PS_LFS_OS_LRC"                    \
                                     ["LFS_MD11407"]="PS_LFS_OS_MD11407"            \
                                     ["LFS_MD11408"]="PS_LFS_OS_MD11408"            \
                                     ["LFS_MD11409"]="PS_LFS_OS_MD11409"            \
                                     ["UBOOT_pronb-developer"]="PS_LFS_BT"          \
                                     ["UBOOT_FSM_R4_DEV"]="PS_LFS_BT_FSM_R4"        \
                                   )

## @fn      getDeliveryRepositoryName( tagName )
#  @brief   get the subversion binary delivery repos name based on the defined regex
#  @param   {tagName}    name of the tag
#  @return  repos name
getDeliveryRepositoryName() {
    local tagName=$1
    mustHaveValue "${tagName}" "name of the tag"

    local reposName=$(sed 's/^.*PS_LFS_OS_\([^_]\+_[^_]\+\)_.*$/BTS_D_SC_LFS_\1/' <<< ${tagName} )
    if [[ ${tagName} = ${reposName} ]] ; then
        error "regex to get SVN delivery repos name didn't match to ${tagName}"
        exit 1
    fi
    debug "svn delivery repos name for ${tagName} is ${reposName}"

    echo ${reposName}
    return
}
