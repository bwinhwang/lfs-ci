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
#  @param   <none>
#  @return  location name
getLocationName() {
    local location=$(${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" location)

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


    export productName=$(getProductNameFromJobName)
    export taskName=$(getTaskNameFromJobName)
    export subTaskName=$(getSubTaskNameFromJobName)
    export location=$(getLocationName)
    export config=$(getTargetBoardName)

    trace "get config value for ${key} using ${file}"
    trace "config/${config}"
    trace "location/${location}"
    trace "subTaskName/${subTaskName}"
    trace "taskName/${taskName}"
    trace "productName/${productName}"

    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/file.cfg
    ${LFS_CI_ROOT}/bin/getConfig -k "${key}" -f ${file}

    return
}


# this is the static configuration, which is valid for all scripting
# stuff in here.
# it must be also valid for all slaves and the master

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
                                 ["arm"]="fsm4_k2"      \
                           ["keystone2"]="fsm4_k2"      \
                                 ["axm"]="fsm4_axm"     \
                            ["fsm4_axm"]="fsm4_axm"     \
                             ["fsm4_k2"]="fsm4_k2"      \
)

# ....
declare -A archMap=(         ["fct"]="mips64-octeon2-linux-gnu"      \
                       ["qemu_i386"]="i686-pc-linux-gnu"             \
                     ["qemu_x86_64"]="x86_64-pc-linux-gnu"           \
                            ["fspc"]="powerpc-e500-linux-gnu"        \
                            ["fcmd"]="powerpc-e500-linux-gnu"        \
                             ["axm"]="arm-cortexa15-linux-gnueabihf" \
                       ["keystone2"]="arm-cortexa15-linux-gnueabihf" \
                        ["fsm4_axm"]="arm-cortexa15-linux-gnueabihf" \
                         ["fsm4_k2"]="arm-cortexa15-linux-gnueabihf" \
)

# maps the location name to the branch name in the svn delivery repos
declare -A locationToSubversionMap=( ["LFS_pronb-developer"]="PS_LFS_OS_MAINBRANCH" \
                                     ["LFS_FSM_R4_DEV"]="PS_LFS_OS_FSM_R4"          \
                                     ["UBOOT_pronb-developer"]="PS_LFS_BT"          \
                                     ["UBOOT_FSM_R4_DEV"]="PS_LFS_BT_FSM_R4"        \
                                   )

declare -a branchToLocationMap=( ["trunk"]="pronb-developer" \
                                 ["fsmr4"]="FSM_R4_DEV" \
                               )

# define the mapping from branch to label/tag name
labelPrefix=$(getConfig labelPrefix)
declare -A branchToTagRegexMap=( ["pronb-developer"]="${labelPrefix}_$(date +%Y)_$(date +%m)_([0-9][0-9])" \
                                      ["FSM_R4_DEV"]="FSMR4_${labelPrefix}_$(date +%Y)_$(date +%m)_([0-9][0-9])" \
                                          ["FB1404"]="FB_${labelPrefix}_1404_04_([0-9][0-9])" \
                                  ["KERNEL_3.x_DEV"]="KERNEL3x_${labelPrefix}_$(date +%Y)_$(date +%m)_([0-9][0-9])" \
                               )

