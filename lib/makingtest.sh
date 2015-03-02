#!/bin/bash
## @file  makingtest.sh
#  @brief common functions for the making test framework

LFS_CI_SOURCE_makingtest='$Id$'

## @fn      makingTest_checkUname()
#  @brief   running a very basic startup test via making test on the target
#  @details this test is starting the target with the new uImage and check, 
#           if the uname -a output contains linux
#  @param   <none>
#  @return  <none>
makingTest_checkUname() {
    requiredParameters JOB_NAME BUILD_NUMBER LABEL DELIVERY_DIRECTORY

    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    local workspace=$(getWorkspaceName)

    # Note: TESTTARGET lowercase with ,,
    local make="make"

    cd ${workspace}/src-test/src/unittest/tests/common/checkuname

    info "writing test config"
    execute ${make} testconfig-overwrite TESTBUILD=${DELIVERY_DIRECTORY} TESTTARGET=${testTargetName,,}

    info "installing software on the target"
    execute ${make} install 

    info "powercycle target"
    execute ${make} powercycle

    info "wait for prompt"
    execute ${make} waitprompt
    execute ${make} waitprompt

    debug "sleep for 60 seconds..."
    sleep 60
    execute ${make} waitprompt

    info "executing checks"
    execute ${make} test

    info "show uptime"
    execute ${make} invoke_console_cmd CMD="uptime"

    info "show kernel version"
    ${make} invoke_console_cmd CMD="uname -a"

    info "testing done."

    return 0
}

## @fn      makingTest_testFSM()
#  @brief   running a whole test suite on the target with making test
#  @details the following making tests commands are executed (simplified)
#            $ make testconfig
#            $ make powercycle
#            $ make install
#            $ make powercycle
#            $ make test
#            $ make poweroff
#  @param   <none>
#  @return  <none>
makingTest_testFSM() {
    requiredParameters JOB_NAME DELIVERY_DIRECTORY

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local testBuildDirectory=${DELIVERY_DIRECTORY}
    mustExistDirectory ${testBuildDirectory}

    local xmlOutputDirectory=${workspace}/xml-output
    execute mkdir -p ${xmlOutputDirectory}
    mustExistDirectory ${xmlOutputDirectory}

	export targetName=$(_reserveTarget)
    mustHaveValue "${testTargetName}" "test target name"

    info "test target name is ${targetName}"

    # we can not use location here, because the job name is "Test-ABC".
    # there is no location in the job name. So we have to use the
    # location of the upstream job.
    export branchName=$(getLocationName ${UPSTREAM_PROJECT})
    mustHaveValue "${branchName}" "branch name"

	local testSuiteDirectory=${workspace}/$(getConfig LFS_CI_uc_test_making_test_suite_dir)
    mustExistDirectory ${testSuiteDirectory}
	mustExistFile ${testSuiteDirectory}/testsuite.mk

    local make="make -C ${testSuiteDirectory}"

    info "create testconfig for ${testSuiteDirectory}"
    execute ${make} testconfig-overwrite \
                TESTBUILD=${testBuildDirectory} \
                TESTTARGET=${testTargetName,,}

    info "powercycle the target to get it in a defined state"
    execute ${make} powercycle

    debug "sleep for 10 seconds..."
    sleep 10

    info "waiting for prompt"
    execute ${make} waitprompt
    # workaround for broken waitprompt / moxa: It seems, that moxa is buffering some data.
    execute ${make} waitprompt 
    execute ${make} waitssh

    debug "sleep for 60 seconds..."
    sleep 60
    info "setup target"
    execute ${make} setup

    local installOptions="$(getConfig LFS_CI_uc_test_making_test_install_options)"
    info "installing software using ${installOptions}"
    execute ${make} install ${installOptions}

    local doFirmwareupgrade="$(getConfig LFS_CI_uc_test_making_test_do_firmwareupgrade)"
    if [[ ${doFirmwareupgrade} ]] ; then
        info "perform firmware upgrade an all boards of $testTargetName."
        execute -i ${make} firmwareupgrade FORCED_UPGRADE=true
    fi

    info "restarting the target"
    execute ${make} powercycle

    debug "sleep for 10 seconds..."
    sleep 10
    execute ${make} waitprompt
    # workaround for broken waitprompt / moxa: It seems, that moxa is buffering some data.
    execute ${make} waitprompt
    execute ${make} waitssh

    debug "sleep for 60 seconds..."
    sleep 60

    info "setup target"
    execute ${make} setup

    info "checking the board for correct software"
    execute ${make} check

    export LFS_CI_ERROR_CODE= 
    info "running test suite"
    execute -i ${make} --ignore-errors test-xmloutput || LFS_CI_ERROR_CODE=0 # also true

    makingTest_copyResults ${testSuiteDirectory}

    if [[ ${LFS_CI_ERROR_CODE} ]] ; then
        error "some errors in test cases. please see logfile"
        exit 1
    fi

    # not all branches have the poweroff implemented
    execute -i ${make} poweroff

    return
}

## @fn      makingTest_copyResults()
#  @brief   copy the results of a test into the artifacts folder
#  @param   {testSuiteDirectory}    directory of the test suite
#  @return  <none>
makingTest_copyResults() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local testSuiteDirectory=$1
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

    # TODO: demx2fk3 2015-02-19 reserve target
    mustHaveValue "${testTargetName}" "test target name"

    local testSuiteDirectory=${workspace}/src-test/src/unittest/testsuites/continousintegration/production_ci_LRC
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

    info "powercycle the target to get it in a defined state"
    execute make -C ${testSuiteDirectory} powercycle
    info "waiting for prompt"
    execute make -C ${testSuiteDirectory} waitssh

    debug "sleep for 120 seconds..."
    sleep 120 

    info "installing software"
    makingTest_install ${testSuiteDirectory}

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
    local testSuiteDirectory=$1
    mustExistDirectory ${testSuiteDirectory}

    local make="make -C ${testSuiteDirectory}"

    info "installing software on target"
    execute ${make} setup

    # currently install does show wrong (old) version after reboot and
    # SHP sometimes fails to be up when install is retried.
    # We try installation up to 4 times
    for i in $(seq 1 4) ; do
        info "install loop ${i}"

        info "running install"
        execute -i ${make} install FORCE=yes || { sleep 20 ; continue ; }
        execute ${make} waitprompt

        info "rebooting target..."
        execute ${make} powercycle FORCE=yes

        info "wait for prompt"
        execute ${make} waitprompt

        info "wait for ssh"
        execute ${make} waitssh

        debug "sleep for 60 seconds..."
        sleep 60

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

