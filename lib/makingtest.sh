#!/bin/bash

LFS_CI_SOURCE_makingtest='$Id$'

fmon_tests() {
    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local wbitSvnUrl=$(build location src-fsmwbit)
    mustHaveValue "${wbitSvnUrl}" "svn ur of src-fsmwbit"

    info "checking out src-fsmtest"
    execute build adddir src-fsmtest
    info "checking out src-ddal"
    execute build adddir src-ddal
    info "checking out src-fsmfmon"
    execute build adddir src-fsmfmon
    info "exporting src-fsmwbit"
    execute build adddir src-fsmwbit
    # execute svn co ${wbitSvnUrl}/src/tools            ${workspace}/src-fsmwbit/src/tools
    # execute svn co ${wbitSvnUrl}/src/test_cases/share ${workspace}/src-fsmwbit/src/test_cases/share
    # execute svn co ${wbitSvnUrl}/src/test_cases/lib   ${workspace}/src-fsmwbit/src/test_cases/lib
    # execute svn co ${wbitSvnUrl}/src/test_cases/lib   ${workspace}/src-fsmwbit/src/test_cases/lib

    execute mkdir -p ${workspace}/src-fsmwbit/src/log/
    execute mkdir -p ${workspace}/xml-reports

    info "start fmon tests..."
    # tell the fmon scripting, where the workspace is. otherwise it will use
    # the hardcoded path /lvol2/production_jenkins/test-repos/...
    export TESTING_WORKSPACE=${workspace}
    execute ${workspace}/src-fsmwbit/src/tools/ftcm/startftcm -cfg ${workspace}/src-fsmtest/src/test_scripts/configs/fcmd15.cfg
    mustExistFile ${workspace}/src-fsmwbit/src/log/tcm2.log

    info "converting fmon log to junit test xml file"
    ${LFS_CI_ROOT}/bin/mkjunitxml.pl ${workspace}/src-fsmwbit/src/log/tcm2.log > ${workspace}/xml-reports/fsmr2.xml
    mustBeSuccessfull "$?" "mkjunitxml.pl"

    return
}

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

makingTest_testFSM() {
    requiredParameters JOB_NAME DELIVERY_DIRECTORY

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local testBuildDirectory=${DELIVERY_DIRECTORY}
    mustExistDirectory ${testBuildDirectory}

    local xmlOutputDirectory=${workspace}/xml-output
    execute mkdir -p ${xmlOutputDirectory}
    mustExistDirectory ${xmlOutputDirectory}

	export targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue "${testTargetName}" "test target name"

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

    info "waiting for prompt"
    execute ${make} waitprompt
    # workaround for broken waitprompt / moxa: It seems, that moxa is buffering some data.
    execute ${make} waitprompt 
    execute ${make} waitssh

    sleep 60
    info "setup target"
    execute ${make} setup

    local installOptions="$(getConfig LFS_CI_uc_test_making_test_install_options)"
    info "installing software using ${installOptions}"
    execute ${make} install ${installOptions}

    local doFirmwareupgrade="$(getConfig LFS_CI_uc_test_making_test_do_firmwareupgrade)"
    if [[ ${doFirmwareupgrade} ]] ; then
        info "perform firmware upgrade an all boards of $testTargetName."
        execute ${make} firmewareupgrade
    fi

    info "restarting the target"
    execute ${make} powercycle
    execute ${make} waitprompt
    # workaround for broken waitprompt / moxa: It seems, that moxa is buffering some data.
    execute ${make} waitprompt
    execute ${make} waitssh

    sleep 60

    info "setup target"
    execute ${make} setup

    info "checking the board for correct software"
    execute ${make} check

    export LFS_CI_ERROR_CODE= 
    info "running test suite"
    execute -i ${make} --ignore-errors test-xmloutput || LFS_CI_ERROR_CODE=0 # also true

    execute mkdir ${workspace}/xml-reports/
    execute cp -f ${testSuiteDirectory}/xml-reports/*.xml ${workspace}/xml-reports/

    if [[ ${LFS_CI_ERROR_CODE} ]] ; then
        error "some errors in test cases. please see logfile"
        exit 1
    fi

    # not all branches have the poweroff implemented
    execute -i ${make} poweroff

    return
}

makingTest_testLRC() {

    requiredParameters DELIVERY_DIRECTORY

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local testBuildDirectory=${DELIVERY_DIRECTORY}
    mustExistDirectory ${testBuildDirectory}

    local xmlOutputDirectory=${workspace}/xml-output
    execute mkdir -p ${xmlOutputDirectory}
    mustExistDirectory ${xmlOutputDirectory}

    local testTargetName=lcpa914 # TODO $(getConfig LFS_CI_uc_test_testTargetName)
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
                TESTBUILD=${testBuildDirectory} \
                TESTTARGET=${testTargetName}

    execute make -C ${testSuiteDirectory_AHP} testconfig-overwrite \
                TESTBUILD=${testBuildDirectory} \
                TESTTARGET=${testTargetName}_ahp

    execute make -C ${testSuiteDirectory_SHP} testconfig-overwrite \
                TESTBUILD=${testBuildDirectory} \
                TESTTARGET=${testTargetName}_shp

    # TODO: demx2fk3 2014-08-13 remove me
    info "powercycle the target to get it in a defined state"
    execute make -C ${testSuiteDirectory} powercycle
    info "waiting for prompt"
    execute make -C ${testSuiteDirectory} waitprompt
    sleep 120 

    info "installing software"
    makingTest_install ${testSuiteDirectory}

    info "checking the board for correct software"
    makingTest_check   ${testSuiteDirectory}
    info "checking the board for correct software SHP"
    makingTest_check   ${testSuiteDirectory_SHP}
    info "checking the board for correct software AHP"
    makingTest_check   ${testSuiteDirectory_AHP}

    export LFS_CI_ERROR_CODE=0
    makingTest_testLRC_subBoard ${testSuiteDirectory_SHP} ${testBuildDirectory} ${testTargetName}_shp shp        ${workspace}/xml-output/shp
    makingTest_testLRC_subBoard ${testSuiteDirectory}     ${testBuildDirectory} ${testTargetName}_shp shp-common ${workspace}/xml-output/shp-common

    execute make -C ${testSuiteDirectory_AHP} waitssh
    execute make -C ${testSuiteDirectory_AHP} setup
    execute make -C ${testSuiteDirectory_AHP} check

    makingTest_testLRC_subBoard ${testSuiteDirectory_AHP} ${testBuildDirectory} ${testTargetName}_ahp ahp        ${workspace}/xml-output/ahp
    makingTest_testLRC_subBoard ${testSuiteDirectory}     ${testBuildDirectory} ${testTargetName}_ahp ahp-common ${workspace}/xml-output/ahp-common

    find ${workspace}/xml-output -name '*.xml' | while read file
    do
        cat -v ${file} > ${file}.tmp && mv ${file}.tmp ${file}
    done
    if [[ ${LFS_CI_ERROR_CODE} ]] ; then
        error "some errors in test cases. please see logfile"
        exit 1
    fi

    return
}

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

    info "testing on target ${testTargetName} in testsuite ${testSuiteDirectory}"
    execute   ${make} clean
    execute   ${make} testconfig-overwrite TESTBUILD=${testBuildDirectory} TESTTARGET=${testTargetName}
    runAndLog ${make} test-xmloutput       || LFS_CI_ERROR_CODE=0 # also true

    execute mkdir -p ${xmlReportDirectory}
    execute cp -rf ${testSuiteDirectory}/xml-reports/* ${xmlReportDirectory}/
    execute sed -i -s "s/name=\"/name=\"${xmlNamePrefix}_/g" ${xmlReportDirectory}/*.xml

    return
}

makingTest_check() {
    local testSuiteDirectory=$1
    mustExistDirectory ${testSuiteDirectory}

    local make="make -C ${testSuiteDirectory}"

    info "recreating testconfig for ${testSuiteDirectory} / ${testBuildDirectory} / ${testTargetName}"
    execute ${make} testconfig-overwrite TESTBUILD=${testBuildDirectory} TESTTARGET=${testTargetName}

    info "waiting for prompt"
    execute ${make} waitprompt

    info "waiting for ssh"
    execute ${make} waitssh

    info "running setup"
    execute ${make} setup

    info "running check"
    execute ${make} check

    return
}

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

        # please note: difference between execute and runAndLog.
        # runAndLog will return the RC of the command. execute will fail, if command fails

        info "running install"
        runAndLog ${make} install FORCE=yes || { sleep 20 ; continue ; }
        execute ${make} waitprompt

        info "rebooting target..."
        execute ${make} powercycle FORCE=yes

        info "wait for prompt"
        execute ${make} waitprompt

        info "wait for setup"
        execute ${make} waitssh

        info "running setup"
        runAndLog ${make} setup || continue

        info "running check"
        runAndLog ${make} check || continue

        info "install was successful"
        break
    done

    return
}

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
    runAndLog ${make} --ignore-errors test-xmloutput || LFS_CI_ERROR_CODE=0 # also true

    execute mkdir ${workspace}/xml-reports/
    execute cp -f ${testSuiteDirectory}/xml-reports/*.xml ${workspace}/xml-reports/

    if [[ ${LFS_CI_ERROR_CODE} ]] ; then
        error "some errors in test cases. please see logfile"
        exit 1
    fi

    return
}
