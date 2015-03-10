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
#           reserveTargetByName targetName
#            or
#           reserveTargetByFeature list of features
#
#           unreserveTarget targetName
#
#           

LFS_CI_SOURCE_booking='$Id$'

## @fn      reserveTargetByName()
#  @brief   reserve target by a given name
#  @details the function will try to reserve the given target. If it does not work, the function will retry
#           up to a configured number of times. After this, it will raise an error.
#  @param   {targetName}    name of the target
#  @return  <none>
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

## @fn      reserveTargetByFeature()
#  @brief   reserve a target by a given list of features
#  @details try to reserve a free target with the given features, if the target is not free, the function will
#           retry it for a configrues amount of times. After this, it will raise an error.
#           The name of the successful reserved target can be get via reservedTarget()
#  @param   {features}    list of features
#  @return  <none>
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

## @fn      reservedTarget()
#  @brief   return the name of the reserved target
#  @param   <none>
#  @return  name of the reserved target
reservedTarget() {
    echo ${LFS_CI_BOOKING_RESERVED_TARGET}
    return
}

## @fn      unreserveTarget()
#  @brief   unreserve a reserved target
#  @param   <none>
#  @return  <none>
unreserveTarget() {
    requiredParameters LFS_CI_BOOKING_RESERVED_TARGET
    local targetName=${LFS_CI_BOOKING_RESERVED_TARGET}
    mustHaveValue "${targetName}" "targetName"

    execute ${LFS_CI_ROOT}/bin/ysmv2.pl --action=unreserveTarget --targetName=${targetName}
    return
}

mustHaveReservedTarget() {
    requiredParameters JOB_NAME

    local isBookingEnabled=$(getConfig LFS_uc_test_is_booking_enabled)
    local targetName=""
    if [[ ${isBookingEnabled} ]] ; then
        # new method via booking from database
        local targetFeatures="$(getConfig LFS_uc_test_booking_target_features)"
        debug "requesting target with features ${targetFeatures}"

        reserveTargetByFeature ${targetFeatures}
        targetName=$(reservedTarget)

        exit_add unreserveTarget
    else
        # old legacy method - from job name            
        targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    fi
    mustHaveValue "${targetName}" "target name"

    return
}

