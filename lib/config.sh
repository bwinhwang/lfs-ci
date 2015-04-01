#!/bin/bash
## @file  config.sh
#  @brief handling of configuration

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
    local jobName=${1:-${JOB_NAME}}

    if [[ -z ${LFS_CI_GLOBAL_BRANCH_NAME} ]] ; then
        local location=$(${LFS_CI_ROOT}/bin/getFromString.pl "${jobName}" location)

        # 2014-02-17 demx2fk3 TODO do this in a better way
        case ${location} in
            fsmr4)    location=FSM_R4_DEV        ;;
            kernel3x) location=KERNEL_3.x_DEV    ;;
            trunk)    location=pronb-developer   ;;
            20M2_09)  location=PS_LFS_OS_20M2_09 ;;
            20M2_12)  location=PS_LFS_OS_20M2_12 ;;
        esac
        export LFS_CI_GLOBAL_BRANCH_NAME=${location}
    fi

    echo ${LFS_CI_GLOBAL_BRANCH_NAME}
    return
}

## @fn      getTaskNameFromJobName()
#  @brief   get the task name from the jenkins job name
#  @param   <none>
#  @return  task name
getTaskNameFromJobName() {
    local jobName=${1:-${JOB_NAME}}
    ${LFS_CI_ROOT}/bin/getFromString.pl "${jobName}" taskName
    return
}

## @fn      getSubTaskNameFromJobName()
#  @brief   get the sub task name from the jenkins job name
#  @param   <none>
#  @return  sub task name
getSubTaskNameFromJobName() {
    local jobName=${1:-${JOB_NAME}}
    ${LFS_CI_ROOT}/bin/getFromString.pl "${jobName}" subTaskName
    return
}

## @fn      getTargetBoardName()
#  @brief   get the target board name from the jenkins job name
#  @param   <none>
#  @return  target board name
getTargetBoardName() {
    local jobName=${1:-${JOB_NAME}}
    ${LFS_CI_ROOT}/bin/getFromString.pl "${jobName}" platform
    return
}


## @fn      getProductNameFromJobName()
#  @brief   get the product name from the job name
#  @param   <none>
#  @return  name of the product
getProductNameFromJobName() {
    local jobName=${1:-${JOB_NAME}}
    ${LFS_CI_ROOT}/bin/getFromString.pl "${jobName}" productName
    return
}

## @fn      getConfig()
#  @brief   get the configuration to the requested key
#  @todo    move this into a generic module. make it also more configureable
#  @param   {key}    key name of the requested value
#  @param   {opt}    -f configFile   name and location of the config file
#  @param   {opt}    -t tags         tags which should also match, 
#                                    multible tags are allowed
#  @return  value for the key
getConfig() {
    local configFile=${LFS_CI_CONFIG_FILE:-${LFS_CI_ROOT}/etc/file.cfg}
    local tags=

    while [[ $# -gt 0 ]] ; do
        case ${1} in
            -f) configFile=${2} ; shift ;;
            -t) tags="-t ${2} ${tags} " ; shift;;
            *) key=${1} ;;
        esac
        shift
    done

    local productName=$(getProductNameFromJobName)
    local location=$(getLocationName)
    local taskName=$(getTaskNameFromJobName)
    local subTaskName=$(getSubTaskNameFromJobName)
    local config=$(getTargetBoardName)

    # TODO: demx2fk3 2014-08-05 this should be always commented out, only required for debugging
    # echo 1>&2 "get config value for ${key} using ${configFile}"
    # echo 1>&2 "tags/${tags}"
    # echo 1>&2 "config/${config}"
    # echo 1>&2 "location/${location}"
    # echo 1>&2 "subTaskName/${subTaskName}"
    # echo 1>&2 "taskName/${taskName}"
    # echo 1>&2 "productName/${productName}"


    ${LFS_CI_ROOT}/bin/getConfig -k "${key}" \
        -f ${configFile}              \
        -t productName:${productName} \
        -t taskName:${taskName}       \
        -t subTaskName:${subTaskName} \
        -t location:${location}       \
        -t config:${config}           \
        ${tags}

    return
}
