#!/bin/bash
## @file  makingtest.sh
#  @brief common functions for the making test framework

LFS_CI_SOURCE_makingtest='$Id$'

## @fn      makingTest_testFSM()
#  @brief   running a whole test suite on the target with making test
#  @details the following making tests commands are executed (simplified)
#            $ make testconfig
#            $ make powercycle
#            $ make install
#            $ make test
#            $ make poweroff
#  @param   <none>
#  @return  <none>
makingTest_testFSM() {

    makingTest_testconfig 
    makingTest_poweron
    makingTest_install    
    makingTest_testXmloutput
    makingTest_copyResults 
    makingTest_poweroff

    return
}

makingTest_testXmloutput() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local xmlOutputDirectory=${workspace}/xml-output
    execute mkdir -p ${xmlOutputDirectory}
    mustExistDirectory ${xmlOutputDirectory}

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    mustHaveMakingTestTestConfig

    info "running test suite"
    execute -i make -C ${testSuiteDirectory} --ignore-errors test-xmloutput

    return
}

makingTest_testconfig() {
    requiredParameters DELIVERY_DIRECTORY

    local targetName=$(_reserveTarget)
    mustHaveValue "${targetName}" "target name"
    
    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    info "create testconfig for ${testSuiteDirectory}"
    execute ${make} testconfig-overwrite        \
                TESTBUILD=${DELIVERY_DIRECTORY} \
                TESTTARGET=${targetName,,}
    return
}

makingTest_testSuiteDirectory() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local targetName=$(_reserveTarget)
    mustHaveValue "${targetName}" "target name"

    # we can not use location here, because the job name is "Test-ABC".
    # there is no location in the job name. So we have to use the
    # location of the upstream job.
    local  branchName=$(getLocationName ${UPSTREAM_PROJECT})
    mustHaveValue "${branchName}" "branch name"

	local testSuiteDirectory=${workspace}/$(getConfig LFS_CI_uc_test_making_test_suite_dir -t targetName:${targetName} -t branchName:${branchName})
    mustExistDirectory ${testSuiteDirectory}
	mustExistFile ${testSuiteDirectory}/testsuite.mk

    return
}

makingTest_poweron() {
    mustHaveMakingTestTestConfig

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    # not all branches have the poweroff implemented
    execute -i make -C ${testSuiteDirectory} poweron

    return
}
makingTest_poweroff() {
    mustHaveMakingTestTestConfig

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    # not all branches have the poweroff implemented
    execute -i make -C ${testSuiteDirectory} poweroff
    return
}

makingTest_powercycle() {
    mustHaveMakingTestTestConfig
    # not all branches have the poweroff implemented

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    info "powercycle the target ..."
    local powercycleOptions=$(getConfig LFS_CI_uc_test_making_test_powercycle_options)
    execute make -C ${testSuiteDirectory} powercycle ${powercycleOptions}
    return
}

## @fn      makingTest_copyResults()
#  @brief   copy the results of a test into the artifacts folder
#  @param   {testSuiteDirectory}    directory of the test suite
#  @return  <none>
makingTest_copyResults() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustHaveMakingTestTestConfig

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    execute mkdir -p ${workspace}/xml-reports/ \
                     ${workspace}/bld/bld-test-xml/results \
                     ${workspace}/bld/bld-test-artifacts/results

    if [[ -d ${testSuiteDirectory}/__artifacts ]] ; then
        execute cp -fr ${testSuiteDirectory}/__artifacts/* ${workspace}/bld/bld-test-artifacts/results/
    fi

    execute cp -fr ${testSuiteDirectory}/xml-reports/*.xml ${workspace}/bld/bld-test-xml/results/
    execute cp -f  ${testSuiteDirectory}/xml-reports/*.xml ${workspace}/xml-reports/

    createArtifactArchive

    return
}

## @fn      makingTest_testLRC()
#  @brief   making test calls for a LRC target
#  @param   <none>
#  @return  <none>
makingTest_testLRC() {

    requiredParameters DELIVERY_DIRECTORY

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local testBuildDirectory=${DELIVERY_DIRECTORY}
    mustExistDirectory ${testBuildDirectory}

    local xmlOutputDirectory=${workspace}/xml-reports
    execute mkdir -p ${xmlOutputDirectory}
    mustExistDirectory ${xmlOutputDirectory}

    local testTargetName=$(_reserveTarget)
    mustHaveValue "${testTargetName}" "test target name"

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    local testSuiteDirectory_SHP=${testSuiteDirectory}_shp
    local testSuiteDirectory_AHP=${testSuiteDirectory}_ahp
    mustExistDirectory ${testSuiteDirectory}
    mustExistDirectory ${testSuiteDirectory_SHP}
    mustExistDirectory ${testSuiteDirectory_AHP}

    execute make -C ${testSuiteDirectory} clean

    info "create testconfig for ${testSuiteDirectory}"
    execute make -C ${testSuiteDirectory} testconfig-overwrite \
                TESTBUILD=${testBuildDirectory}                \
                TESTTARGET=${testTargetName}

    execute make -C ${testSuiteDirectory_AHP} testconfig-overwrite \
                TESTBUILD=${testBuildDirectory}                    \
                TESTTARGET=${testTargetName}_ahp

    execute make -C ${testSuiteDirectory_SHP} testconfig-overwrite \
                TESTBUILD=${testBuildDirectory}                    \
                TESTTARGET=${testTargetName}_shp

    makingTest_powercycle
    info "waiting for prompt"
    execute make -C ${testSuiteDirectory} waitssh

    debug "sleep for 120 seconds..."
    sleep 120 

    info "installing software"
    makingTest_install 

    info "checking the board for correct software"
    makingTest_check   ${testSuiteDirectory}     ${testTargetName}
    info "checking the board for correct software SHP"
    makingTest_check   ${testSuiteDirectory_SHP} ${testTargetName}_shp
    info "checking the board for correct software AHP"
    makingTest_check   ${testSuiteDirectory_AHP} ${testTargetName}_ahp

    makingTest_testLRC_subBoard ${testSuiteDirectory_SHP} ${testBuildDirectory} ${testTargetName}_shp shp        ${xmlOutputDirectory}/shp
    makingTest_testLRC_subBoard ${testSuiteDirectory}     ${testBuildDirectory} ${testTargetName}_shp shp-common ${xmlOutputDirectory}/shp-common

    execute make -C ${testSuiteDirectory_AHP} waitssh
    debug "sleep for 60 seconds..."
    sleep 60
    execute make -C ${testSuiteDirectory_AHP} setup
    execute make -C ${testSuiteDirectory_AHP} check

    makingTest_testLRC_subBoard ${testSuiteDirectory_AHP} ${testBuildDirectory} ${testTargetName}_ahp ahp        ${xmlOutputDirectory}/ahp
    makingTest_testLRC_subBoard ${testSuiteDirectory}     ${testBuildDirectory} ${testTargetName}_ahp ahp-common ${xmlOutputDirectory}/ahp-common

    find ${workspace}/xml-output -name '*.xml' | while read file ; do
        cat -v ${file} > ${file}.tmp && mv ${file}.tmp ${file}
    done

    execute -i make -C ${testSuiteDirectory} poweroff

    return
}

## @fn      makingTest_testLRC_subBoard()
#  @brief   run a test suite for LRC on a LRC sub board (ahp, shp, ..)
#  @param   {testSuiteDirectory}    directory of the test suite
#  @param   {targetName}            name of the target
#  @param   {testBuildDirectory}    directory of the build / software
#  @param   {xmlNamePrefix}         prefix of the xml test results
#  @param   {xmlReportDirectory}    directory of the xml report
#  @return  <none>
makingTest_testLRC_subBoard() {
    local testSuiteDirectory=$1
    mustExistDirectory ${testSuiteDirectory}

    local testBuildDirectory=$2
    mustExistDirectory ${testBuildDirectory}

    local testTargetName=$3
    mustHaveValue "${testTargetName}" "test target name"

    local xmlNamePrefix=$4
    mustHaveValue "${xmlNamePrefix}" "xml name prefix"

    local xmlReportDirectory=$5
    execute mkdir -p ${xmlReportDirectory}
    mustExistDirectory ${xmlReportDirectory}

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local make="make -C ${testSuiteDirectory}"

    info "running tests on target ${testTargetName} for testsuite ${testSuiteDirectory//${workspace}}"
    execute    ${make} clean
    execute    ${make} testconfig-overwrite TESTBUILD=${testBuildDirectory} TESTTARGET=${testTargetName}
    execute    ${make} setup
    execute    ${make} check
    execute -i ${make} -i test-xmloutput

    execute mkdir -p ${xmlReportDirectory}
    execute cp -rf ${testSuiteDirectory}/xml-reports/* ${xmlReportDirectory}/
    execute sed -i -s "s/name=\"/name=\"${xmlNamePrefix}_/g" ${xmlReportDirectory}/*.xml

    return
}

## @fn      makingTest_check()
#  @brief   checks, if a target is up and running and is running with the
#           correct software version
#  @param   {testSuiteDirectory}  directory of the test suite
#  @param   {targetName}          name of the target
#  @return  <none>
makingTest_check() {
    local testSuiteDirectory=${1}
    mustExistDirectory ${testSuiteDirectory}

    local testTargetName=${2}
    mustHaveValue "${testTargetName}" "test target name"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local make="make -C ${testSuiteDirectory}"

    info "recreating testconfig for ${testSuiteDirectory//${workspace}} / $(basename ${testBuildDirectory}) / ${testTargetName}"
    execute ${make} testconfig-overwrite TESTBUILD=${testBuildDirectory} TESTTARGET=${testTargetName}

    info "waiting for prompt"
    execute ${make} waitprompt

    info "waiting for ssh"
    execute ${make} waitssh

    debug "sleep for 60 seconds..."
    sleep 60

    info "running setup"
    execute ${make} setup

    info "running check"
    execute ${make} check

    return
}

## @fn      makingTest_install()
#  @brief   install a software load via making test on the target
#  @warning this is only used by LRC at the moment, but should also work for FSM
#  @param   {testSuiteDirectory}    directory of a test suite
#  @return  <none>
makingTest_install() {
    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    local make="make -C ${testSuiteDirectory}"

    mustHaveMakingTestRunningTarget

    info "installing software on target"
    execute ${make} setup

    # on LRC: currently install does show wrong (old) version after reboot and
    # SHP sometimes fails to be up when install is retried.
    # We try installation up to 4 times
    for i in $(seq 1 4) ; do
        info "install loop ${i}"

        info "running install"
        execute -i ${make} install FORCE=yes || { sleep 20 ; continue ; }
        execute ${make} waitprompt

        local doFirmwareupgrade="$(getConfig LFS_CI_uc_test_making_test_do_firmwareupgrade)"
        if [[ ${doFirmwareupgrade} ]] ; then
            info "perform firmware upgrade an all boards of $testTargetName."
            execute -i ${make} firmwareupgrade FORCED_UPGRADE=true
        fi

        info "rebooting target..."
        makingTest_powercycle

        mustHaveMakingTestRunningTarget

        info "running setup"
        execute -i ${make} setup || continue

        info "running check"
        execute -i ${make} check || continue

        info "install was successful"
        break
    done

    return
}

## @fn      makingTest_testsWithoutTarget()
#  @brief   run a test suite, which do not need a real target.
#  @param   <none>
#  @return  <none>
makingTest_testsWithoutTarget() {
    requiredParameters JOB_NAME DELIVERY_DIRECTORY

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local testBuildDirectory=${DELIVERY_DIRECTORY}
    mustExistDirectory ${testBuildDirectory}

    local xmlOutputDirectory=${workspace}/xml-output
    execute mkdir -p ${xmlOutputDirectory}
    mustExistDirectory ${xmlOutputDirectory}

	local testSuiteDirectory=${workspace}/$(getConfig LFS_CI_uc_test_making_test_suite_dir)
    mustExistDirectory ${testSuiteDirectory}
	mustExistFile ${testSuiteDirectory}/testsuite.mk

    local make="make -C ${testSuiteDirectory}"

    info "create testconfig for ${testSuiteDirectory}"
    execute ${make} testconfig-overwrite \
                TESTBUILD=${testBuildDirectory} 

    export LFS_CI_ERROR_CODE= 
    info "running test suite"
    execute -i ${make} --ignore-errors test-xmloutput || LFS_CI_ERROR_CODE=0 # also true

    makingTest_copyResults ${testSuiteDirectory}

    if [[ ${LFS_CI_ERROR_CODE} ]] ; then
        error "some errors in test cases. please see logfile"
        exit 1
    fi

    return
}

## @fn      _reserveTarget
#  @brief   make a reserveration from TAToo/YSMv2 to get a target name
#  @param   <none>
#  @return  name of the target
_reserveTarget() {

    requiredParameters JOB_NAME
    local isBookingEnabled=$(getConfig LFS_uc_test_is_booking_enabled)
    local targetName=""

    if [[ ${isBookingEnabled} ]] ; then
        # new method via booking from database
        targetName=$(reservedTarget)
    else
        targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    fi
    mustHaveValue ${targetName} "target name"

    echo ${targetName}
   
    return
}

mustHaveMakingTestTestConfig() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

	local testSuiteDirectory=${workspace}/$(getConfig LFS_CI_uc_test_making_test_suite_dir)
    mustExistDirectory ${testSuiteDirectory}
	mustExistFile ${testSuiteDirectory}/testsuite.mk

    [[ -e ${testSuiteDirectory}/testconfig.mk ]] && return
    makingTest_testconfig
    return
}

mustHaveMakingTestRunningTarget() {

    mustHaveMakingTestTestConfig

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

	local testSuiteDirectory=${workspace}/$(getConfig LFS_CI_uc_test_making_test_suite_dir)
    mustExistDirectory ${testSuiteDirectory}
	mustExistFile ${testSuiteDirectory}/testsuite.mk

    execute make -C ${testSuiteDirectory} waitprompt
    execute make -C ${testSuiteDirectory} waitssh
    sleep 60

    return
}
