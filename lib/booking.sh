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

reserveTargetByName() {
    local targetName=${1}
    mustHaveValue "${targetName}" "targetName"

    local counter=0
    local sleepTime=$(getConfig LFS_CI_uc_test_booking_target_sleep_seconds)
    mustHaveValue "${sleepTime}" "sleep time"

    local maxTryToGetTarget=$(getConfig LFS_CI_uc_test_booking_target_max_tries)
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
    done

    fatal "reservation for target ${targetName} was not successfully"
    return
}

reserveTargetByFeature() {
    local featrues=${@}
    mustHaveValue "${featrues}" "list of features"

    local searchParameter=""
    for p in ${features} ; do
        searchParameter="${searchParameter} --attribure=${p}"
    done

    local results=$(createTempFile)
    for targetName in $(execute -n ysmv2.pl --action=searchTarget ${searchParameter} ) ; do
        debug "try to reserve target ${targetName}"

        if execute -i ${LFS_CI_ROOT}/bin/ysmv2.pl --action=reserveTarget --targetName=${targetName} ; then
            info "reservation for target ${targetName} was successful"
            export LFS_CI_BOOKING_RESERVED_TARGET=${targetName}
            return
        fi
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


