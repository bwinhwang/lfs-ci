#!/bin/bash

[[ -z ${LFS_CI_SOURCE_booking}         ]] && source ${LFS_CI_ROOT}/lib/booking.sh
[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

usecase_LAB_REPAIR_TARGET() {
    requiredParameters REPAIR_TARGET_NAME

    local targetName=${REPAIR_TARGET_NAME}
    mustHaveValue "${targetName}" "target name to repair"

    reserveTargetByName ${targetName}

    local targetType=$(getConfig LFS_CI_uc_test_target_type_mapping -t jobName:${targetName})
    mustHaveValue "${targetType}" "target type"

    local location=""
    case ${targetType} in
        FSM-r3) location=pronb-developer ;;
        *)      fatal "target type ${targetType} is not supported" ;;
    esac
        
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    createBasicWorkspace -l ${location} src-test

    info "testing target in repair center..."
    execute cd ${workspace}/src-test/src/unittest/testtarget/actions/recover_partition_switch
    execute make testconfig TESTTARGET=${targetName,,} 

    info "starting target..."
    execute make powercycle
    execute make waitprompt

    info "prompt is up, try to recover the target by partition switch"
    execute make test

    execute make poweroff

    unreserveTarget

    return
}

