#!/bin/bash
## @file    booking.sh
#  @brief   functions about booking of targets in the lab
#  @details This functions are handling the booking (aka reservation) of targets in the lab.
#           The current implementation is just a prove of concept and supports very limited
#           features. Currently you can only reserve, unreserve and search targets.
#
#           The database handles only the target information with some features keys.
#           There are no configuration parameters like powertab and moxa in the database.
#           These informations must be already configured in making test.
#           (FMON tests is currently not supported)
#
#           How it should work:
#
#           reserveTargetByName <targetName>
#            or
#           reserveTargetByFeature <list of features>
#
#           unreserveTarget <targetName>
#
#           

LFS_CI_SOURCE_booking='$Id$'

reserveTargetByName() {
    local targetName=${1}
    mustHaveValue "${targetName}" "targetName"

    local counter=0
    local sleepTime=$(getConfig LFS_uc_test_booking_target_sleep_seconds)
    mustHaveValue "${sleepTime}" "sleep time"

    local maxTryToGetTarget=$(getConfig LFS_uc_test_booking_target_max_tries)
    mustHaveValue "${maxTryToGetTarget}" "max tries to get target"

    while [[ ${counter} -lt ${maxTryToGetTarget} ]] ; do
        if execute -i ${LFS_CI_ROOT}/bin/ysmv2.pl --action=reserveTarget --targetName=${targetName} ; then
            info "reservation for target ${targetName} was successful"
            export LFS_CI_BOOKING_RESERVED_TARGET=${targetName}
            return
        else
            warning "reservation for target ${targetName} was not successful, retry in ${sleepTime} s"
            sleep ${sleepTime}
        fi
        counter=$((counter + 1))
    done

    fatal "reservation for target ${targetName} was not successfully"
    return
}

reserveTargetByFeature() {
    local features=${@}
    mustHaveValue "${features}" "list of features"

    debug "features ${features}"
    local searchParameter=""
    for p in ${features} ; do
        searchParameter="${searchParameter} --attribute=${p}"
    done

    debug "search parameter: ${searchParameter}"

    local sleepTime=$(getConfig LFS_uc_test_booking_target_sleep_seconds)
    mustHaveValue "${sleepTime}" "sleep time"

    local maxTryToGetTarget=$(getConfig LFS_uc_test_booking_target_max_tries)
    mustHaveValue "${maxTryToGetTarget}" "max tries to get target"

    local counter=0

    while [[ ${counter} -lt ${maxTryToGetTarget} ]] ; do
        for targetName in $(execute -n ${LFS_CI_ROOT}/bin/ysmv2.pl --action=searchTarget ${searchParameter} ) ; do
            info "try to reserve target ${targetName}"

            if execute -i ${LFS_CI_ROOT}/bin/ysmv2.pl --action=reserveTarget --targetName=${targetName} ; then
                info "reservation for target ${targetName} was successful"
                export LFS_CI_BOOKING_RESERVED_TARGET=${targetName}
                return
            fi
        done
        info "no free target, will try in ${sleepTime} s (total try ${counter})"
        counter=$((counter + 1))
        sleep ${sleepTime}
    done

    fatal "reservation for target with features ${features} was not successfully"
    return
}

reservedTarget() {
    echo ${LFS_CI_BOOKING_RESERVED_TARGET}
    return
}

unreserveTarget() {
    requiredParameters LFS_CI_BOOKING_RESERVED_TARGET
    local targetName=${LFS_CI_BOOKING_RESERVED_TARGET}
    mustHaveValue "${targetName}" "targetName"

    execute ${LFS_CI_ROOT}/bin/ysmv2.pl --action=unreserveTarget --targetName=${targetName}
    return
}


