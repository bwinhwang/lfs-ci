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

## @fn      makingTest_testsWithoutTarget()
#  @brief   run a test suite, which do not need a real target.
#  @param   <none>
#  @return  <none>
makingTest_testsWithoutTarget() {
    makingTest_testconfig
    makingTest_testXmloutput
    makingTest_copyResults

    return
}

## @fn      makingTest_testXmloutput()
#  @brief   running TMF tests on the target and create XML output
#  @details this is just a make test-xmloutput with some options
#  @param   <none>
#  @return  <none>
makingTest_testXmloutput() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local xmlOutputDirectory=${workspace}/xml-output
    execute mkdir -p ${xmlOutputDirectory}
    mustExistDirectory ${xmlOutputDirectory}

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    local testOptions=$(getConfig LFS_CI_uc_test_making_test_test_options)

    mustHaveMakingTestTestConfig

    info "running test suite"
    execute -i make -C ${testSuiteDirectory}      \
                    --ignore-errors ${testOptions}\
                    test-xmloutput

    return
}

## @fn      makingTest_testconfig()
#  @brief   create a test configuration (testconfig.mk) for making test 
#           in the test suite directory
#  @param   <none>
#  @return  <none>
makingTest_testconfig() {
    local targetName="$(_reserveTarget)"
    mustHaveValue "${targetName}" "target name"
    
    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    local deliveryDirectory=$(getConfig LFS_CI_uc_test_on_target_delivery_directory)
    mustExistDirectory ${deliveryDirectory}

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    info "create testconfig for ${testSuiteDirectory}"
    execute make -C ${testSuiteDirectory}       \
                testconfig-overwrite            \
                TESTBUILD=${deliveryDirectory}  \
                TESTTARGET="${targetName,,}"    \
                TESTBUILD_SRC=${workspace}
    return
}

## @fn      makingTest_testSuiteDirectory()
#  @brief   get the test suite directory from the configuration
#  @param   <none>
#  @return  path to the test suite directory
makingTest_testSuiteDirectory() {
    requiredParameters UPSTREAM_PROJECT

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local targetName=$(_reserveTarget)
    mustHaveValue "${targetName}" "target name"

    # we can not use location here, because the job name is "Test-ABC".
    # there is no location in the job name. So we have to use the
    # location of the upstream job.
    local  branchName=$(getLocationName ${UPSTREAM_PROJECT})
    mustHaveValue "${branchName}" "branch name"

    local relativeTestSuiteDirectory=
    if [[ -e ${workspace}/src-project/src/TMF/testsuites.cfg ]] ; then
        relativeTestSuiteDirectory=$(getConfig test_suite                               \
                                            -t targetName:${targetName}                      \
                                            -t branchName:${branchName}                      \
                                            -f ${workspace}/src-project/src/TMF/testsuites.cfg)

    fi
    # if test suite directory is empty, try to find in test suite in the old config file
    if [[ -z ${relativeTestSuiteDirectory} ]] ; then
        relativeTestSuiteDirectory=$(getConfig LFS_CI_uc_test_making_test_suite_dir \
                                            -t targetName:${targetName}                  \
                                            -t branchName:${branchName}                  )
    fi
    local testSuiteDirectory=${workspace}/${relativeTestSuiteDirectory}
    mustExistDirectory ${testSuiteDirectory}
    mustExistFile ${testSuiteDirectory}/testsuite.mk

    trace "using test suite ${testSuiteDirectory} for target ${targetName} and branch ${branchName}"
    echo ${testSuiteDirectory}

    return
}

## @fn      makingTest_poweron()
#  @brief   turn the power on on a target
#  @param   <none>
#  @return  <none>
makingTest_poweron() {
    mustHaveMakingTestTestConfig

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    makingTest_logConsole

    # This should be a poweron, but we don't know the state of the target.
    # So we just powercycle the target
    execute make -C ${testSuiteDirectory} powercycle

    return
}

## @fn      makingTest_poweroff()
#  @brief   turn the power off on a target
#  @param   <none>
#  @return  <none>
makingTest_poweroff() {
    mustHaveMakingTestTestConfig

    local testSuiteDirectory=$(makingTest_testSuiteDirectory)
    mustExistDirectory ${testSuiteDirectory}

    # not all branches have the poweroff implemented
    execute -i make -C ${testSuiteDirectory} poweroff
    makingTest_closeConsole

    return
}

## @fn      makingTest_powercycle()
#  @brief   powercycle a target
#  @param   <none>
#  @return  <none>
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
#  @param   <none>
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
    mustExistDirectory ${testSuiteDirectory}/
    mustExistDirectory ${testSuiteDirectory_SHP}/
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
    mustHaveMakingTestRunningTarget

    info "installing software"
    makingTest_install 

    info "checking the board for correct software"
    makingTest_testLRC_check   ${testSuiteDirectory}     ${testTargetName}
    info "checking the board for correct software SHP"
    makingTest_testLRC_check   ${testSuiteDirectory_SHP} ${testTargetName}_shp
    info "checking the board for correct software AHP"
    makingTest_testLRC_check   ${testSuiteDirectory_AHP} ${testTargetName}_ahp

    makingTest_testLRC_subBoard ${testSuiteDirectory_SHP} ${testBuildDirectory} ${testTargetName}_shp shp        ${xmlOutputDirectory}/shp
    makingTest_testLRC_subBoard ${testSuiteDirectory}     ${testBuildDirectory} ${testTargetName}_shp shp-common ${xmlOutputDirectory}/shp-common

    mustHaveMakingTestRunningTarget
    execute make -C ${testSuiteDirectory_AHP} setup
    execute make -C ${testSuiteDirectory_AHP} check

    makingTest_testLRC_subBoard ${testSuiteDirectory_AHP} ${testBuildDirectory} ${testTargetName}_ahp ahp        ${xmlOutputDirectory}/ahp
    makingTest_testLRC_subBoard ${testSuiteDirectory}     ${testBuildDirectory} ${testTargetName}_ahp ahp-common ${xmlOutputDirectory}/ahp-common

    find ${xmlOutputDirectory} -name '*.xml' | while read file ; do
        cat -v ${file} > ${file}.tmp && mv ${file}.tmp ${file}
    done

    makingTest_poweroff

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

## @fn      makingTest_testLRC_check()
#  @brief   checks, if a target is up and running and is running with the
#           correct software version
#  @param   {testSuiteDirectory}  directory of the test suite
#  @param   {targetName}          name of the target
#  @return  <none>
makingTest_testLRC_check() {
    local testSuiteDirectory=${1}
    mustExistDirectory ${testSuiteDirectory}

    local testTargetName=${2}
    mustHaveValue "${testTargetName}" "test target name"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local make="make -C ${testSuiteDirectory}"

    info "recreating testconfig for ${testSuiteDirectory//${workspace}} / $(basename ${testBuildDirectory}) / ${testTargetName}"
    execute ${make} testconfig-overwrite TESTBUILD=${testBuildDirectory} TESTTARGET=${testTargetName}

    mustHaveMakingTestRunningTarget

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

    local targetName=$(_reserveTarget)
    mustHaveValue "${targetName}" "target name"

    local shouldHaveRunningTarget=$(getConfig LFS_CI_uc_test_should_target_be_running_before_make_install)
    if [[ ${shouldHaveRunningTarget} ]] ; then
        mustHaveMakingTestRunningTarget

        info "installing software on target"
        execute ${make} setup

        local forceInstallSameVersion=$(getConfig LFS_CI_uc_test_making_test_force_reinstall_same_version)
        if [[ -z ${forceInstallSameVersion} ]] ; then
            if execute -i ${make} check ; then
                info "the version, we would install is already on the target, skipping install"
                return
            else
                info "ignore the warning above. It just saying, that the software version, we want to install is not yet on the target."                
            fi
        fi
    fi

    # on LRC: currently install does show wrong (old) version after reboot and
    # SHP sometimes fails to be up when install is retried.
    # We try installation up to 4 times
    for i in $(seq 1 4) ; do
        trace "install loop ${i}"

        local installOptions=$(getConfig LFS_CI_uc_test_making_test_install_options -t testTargetName:${targetName})
        info "running install with options ${installOptions:-none}"
        execute -i ${make} install ${installOptions} FORCE=yes || { sleep 20 ; continue ; }

        local doFirmwareupgrade="$(getConfig LFS_CI_uc_test_making_test_do_firmwareupgrade)"
        if [[ ${doFirmwareupgrade} ]] ; then
            info "perform firmware upgrade an all boards of $testTargetName."
            execute -i ${make} firmwareupgrade FORCED_UPGRADE=true
        fi

        info "rebooting target..."
        makingTest_powercycle

        mustHaveMakingTestRunningTarget

        info "running setup..."
        execute -i ${make} setup || continue

        info "running check..."
        execute -i ${make} check || continue

        info "install was successful."

        return
    done

    fatal "installation failed after four attempts."

    return
}

## @fn      _reserveTarget
#  @brief   make a reserveration from TAToo/YSMv2 to get a target name
#  @param   <none>
#  @return  name of the target
_reserveTarget() {
    requiredParameters JOB_NAME

    local isBookingEnabled=$(getConfig LFS_uc_test_is_booking_enabled)
    local isCloudEnabled=$(getConfig LFS_CI_uc_test_is_cloud_enabled)
    local targetName=""
    if   [[ ${isCloudEnabled}   ]] ; then
        targetName=$(getConfig LFS_CI_uc_test_cloud_testconfig_target_parameter)
    elif [[ ${isBookingEnabled} ]] ; then
        # new method via booking from database
        targetName=$(reservedTarget)
    else
        targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    fi
    mustHaveValue ${targetName} "target name"

    echo ${targetName}
   
    return
}

## @fn      mustHaveMakingTestTestConfig()
#  @brief   ensures, that there is a testconfig.mk in the testsuite directory
#  @param   <none>
#  @return  <none>
mustHaveMakingTestTestConfig() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

	local testSuiteDirectory=$(makingTest_testSuiteDirectory)
	mustExistDirectory ${testSuiteDirectory}

    [[ -e ${testSuiteDirectory}/testconfig.mk ]] && return
    makingTest_testconfig
    return
}

## @fn      mustHaveMakingTestRunningTarget()
#  @brief   ensures, that the test target is up and running with ssh
#  @param   <none>
#  @return  <none>
mustHaveMakingTestRunningTarget() {

    mustHaveMakingTestTestConfig

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

	local testSuiteDirectory=$(makingTest_testSuiteDirectory)
	mustExistFile ${testSuiteDirectory}/testsuite.mk

    info "checking, if target is up and running (with ssh)..."
    local canDoWaitPrompt=$(getConfig LFS_CI_uc_test_TMF_can_run_waitprompt)
    if [[ ${canDoWaitPrompt} ]] ; then
        execute make -C ${testSuiteDirectory} waitprompt
    fi
    execute make -C ${testSuiteDirectory} waitssh
    debug "sleeping for 60 seconds..."
    execute sleep 60

    info "target is up."

    return
}


## @fn      makingTest_logConsole()
#  @brief   start to log all console output into an artifacts file
#  @param   <none>
#  @return  <none>
makingTest_logConsole() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local shouldLogConsole=$(getConfig LFS_CI_uc_test_should_record_log_output_of_target)
    [[ ${shouldLogConsole} ]] || return 0

	local testSuiteDirectory=$(makingTest_testSuiteDirectory)
	mustExistFile ${testSuiteDirectory}/testsuite.mk

    mustHaveMakingTestTestConfig

    local logfilePath=${testSuiteDirectory}/__artifacts 
    execute mkdir -p ${logfilePath}

    local screenConfig=${WORKSPACE}/workspace/screenrc
    cat <<EOF > ${screenConfig}
logfile ${logfilePath}/console.%n
logfile flush 1
logtstamp after 10
EOF
    local make="make -C ${testSuiteDirectory} testtarget-analyzer | grep "
    local fctTarget=$(_reserveTarget)
    local fspTargets=$(execute -n ${make} setupfsps | cut -d= -f2 | tr "," " ")

    for target in ${fctTarget,,} ${fspTargets,,} ; do
        local moxa=$(execute -n ${make} moxa | cut -d= -f2)
        if [[ ${moxa} ]] ; then
            local localPort=$(sed "s/[\.:\]//g" )
            localPort=$(( localPort % 64000 + 1024 ))
            echo "screen -L -t tp_${target} ${LFS_CI_ROOT}/lib/contrib/tcp_sharer/tcp_sharer.pl --name ${target} --logfile ${logfilePath}/tp_${target}.log --remove ${moxa} --local ${localPort}" >> ${screenConfig}
            echo "screen -L -t ${target}    sleep 3 && make -C ${testSuiteDirectory} TESTTARGET=${target} console" >> ${screenConfig}
        fi
    done

    rawDebug ${screenConfig}

    export LFS_CI_UC_TEST_SCREEN_NAME=lfs-jenkins.${USER}.${fctTarget}
    execute screen -S ${LFS_CI_UC_TEST_SCREEN_NAME} -L -d -m -c ${screenConfig}
    exit_add makingTest_closeConsole

     return
}

## @fn      makingTest_closeConsole()
#  @brief   stop to log all console output into an artifacts file
#  @param   <none>
#  @return  <none>
makingTest_closeConsole() {
    execute -i screen -dr -S ${LFS_CI_UC_TEST_SCREEN_NAME} -X quit
    return
}
