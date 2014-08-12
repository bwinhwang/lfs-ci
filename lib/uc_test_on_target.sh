#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins} ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

ci_job_test_on_target() {
    requiredParameters JOB_NAME BUILD_NUMBER LABEL DELIVERY_DIRECTORY

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${LABEL}

    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    info "create workspace for testing"
    cd ${workspace}
    execute build setup
    execute build adddir src-test

    export testTargetName=${targetName}
    local testType=$(getConfig LFS_CI_uc_test_making_test_type)

    case ${testType} in
        checkUname)
            makingTest_checkUname
        ;;
        testProductionLRC)
            makingTest_testLRC
        ;;
    esac

    return

}
makingTest_checkUname() {
    requiredParameters JOB_NAME BUILD_NUMBER LABEL DELIVERY_DIRECTORY

    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    local workspace=$(getWorkspaceName)

    # Note: TESTTARGET lowercase with ,,
    local make="make TESTTARGET=${targetName,,}"    

    cd ${workspace}/src-test/src/unittest/tests/common/checkuname
    info "installing software on the target"
    execute ${make} install WORKSPACE=${DELIVERY_DIRECTORY} 

    info "powercycle target"
    execute ${make} powercycle

    info "wait for prompt"
    sleep 60
    execute ${make} waitprompt

    info "executing checks"
    execute ${make} test

    info "show uptime"
    execute ${make} invoke_console_cmd CMD=uptime

    info "show kernel version"
    ${make} invoke_console_cmd CMD="uname -a"

    info "testing done."

    return 0
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

    local testTargetName=lcpa878 # TODO $(getConfig LFS_CI_uc_test_testTargetName)
    mustHaveValue "${testTargetName}" "test target name"

    local testSuiteDirectory=${workspace}/src-test/src/unittest/testsuites/continousintegration/production_ci_LRC
    local testSuiteDirectory_SHP=${testSuiteDirectory}_shp
    local testSuiteDirectory_AHP=${testSuiteDirectory}_ahp
    mustExistDirectory ${testSuiteDirectory}
    mustExistDirectory ${testSuiteDirectory_SHP}
    mustExistDirectory ${testSuiteDirectory_AHP}

    info "create testconfig for ${testSuiteDirectory}"
    execute make -C ${testSuiteDirectory} testconfig-overwrite \
                TESTBUILD=${testBuildDirectory} \
                TESTTARGET=${testTargetName}

    makingTest_install ${testSuiteDirectory}

    makingTest_check   ${testSuiteDirectory}
    makingTest_check   ${testSuiteDirectory_SHP}
    makingTest_check   ${testSuiteDirectory_AHP}

    makingTest_testLRC_subBoard ${testSuiteDirectory_SHP} ${testBuildDirectory} ${testTargetName}_shp ${workspace}/xml-output/shp
    makingTest_testLRC_subBoard ${testSuiteDirectory}     ${testBuildDirectory} ${testTargetName}_shp ${workspace}/xml-output/shp-common

    execute make -C ${testSuiteDirectory_AHP} waitssh
    execute make -C ${testSuiteDirectory_AHP} setup
    execute make -C ${testSuiteDirectory_AHP} check

    makingTest_testLRC_subBoard ${testSuiteDirectory_AHP} ${testBuildDirectory} ${testTargetName}_ahp ${workspace}/xml-output/ahp
    makingTest_testLRC_subBoard ${testSuiteDirectory}     ${testBuildDirectory} ${testTargetName}_ahp ${workspace}/xml-output/ahp-common

    find ${workspace}/xml-output -name '*.xml' | while read file
    do
        cat -v ${file} > ${file}.tmp && mv ${file}.tmp ${file}
    done
    # exit $E

    return
}

makingTest_testLRC_subBoard() {
    local testSuiteDirectory=$1
    mustExistDirectory ${testSuiteDirectory}

    local testBuildDirectory=$2
    mustExistDirectory ${testBuildDirectory}

    local testTargetName=$3
    mustHaveValue "${testTargetName}" "test target name"

    local xmlReportDirectory=$4
    execute mkdir -p ${xmlReportDirectory}
    mustExistDirectory ${xmlReportDirectory}

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local make="make -C ${testSuiteDirectory}"

    execute ${make} clean
    execute ${make} testconfig-overwrite TESTBUILD=${testBuildDirectory} TESTTARGET=${testTargetName}
            ${make} test-xmloutput       || E=0 # also true

    execute mkdir -p ${xmlReportDirectory}
    execute cp -rf ${testSuiteDirectory}/xml-reports ${xmlReportDirectory}
    execute sed -i -s 's/name=/name=ahp_common_/g' ${xmlReportDirectory}/xml-reports/*.xml

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

        # TODO: demx2fk3 2014-08-12 remove me
        info "running check"
        runAndLog ${make} check && break

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
