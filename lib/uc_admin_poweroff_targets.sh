[[ -z ${LFS_CI_SOURCE_booking}         ]] && source ${LFS_CI_ROOT}/lib/database.sh
[[ -z ${LFS_CI_SOURCE_makingtest}      ]] && source ${LFS_CI_ROOT}/lib/makingtest.sh
[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

## @fn      usecase_ADMIN_TARGETS_POWER_OFF()
#  @brief   turn of the unused targets after x hours
#  @param   <none>
#  @return  <none>
usecase_ADMIN_TARGETS_POWER_OFF() {

    export DELIVERY_DIRECTORY=/build/home/CI_LFS/Release_Candidates/FSMr3/latest_trunk/.
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Test

    createBasicWorkspace -l pronb-developer src-test 
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    echo "test_suite = src-test/src/testsuites/continousintegration/smoketest" > ${workspace}/src-project/src/TMF/testsuites.cfg
    
    for target in $(${LFS_CI_ROOT}/bin/unusedTargets) ; do

        info "power off target ${target}"
        reserveTargetByName ${target,,}
        makingTest_testconfig
        makingTest_poweroff
        unreserveTarget

    done

    return
}
