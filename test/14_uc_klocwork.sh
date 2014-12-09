#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/uc_klocwork.sh

export UNITTEST_COMMAND=$(createTempFile)
export UT_BUILD_SRC_LIST=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UNITTEST_COMMAND}
    }
    exit_handler() {
        echo exit
    }
    mustHaveValue() {
        mockedCommand "mustHaveValue $@"
        return
    }
    execute() {
        mockedCommand "execute $@"
    }
    createOrUpdateWorkspace() {
        mockedCommand "createOrUpdateWorkspace $@"
    }
    createTempFile() {
        mockedCommand "createTempFile"
        echo /tmp/file
    }

    getTargetBoardName() {
        mockedCommand "getTargetBoardName"
        echo PS_LFS_DDAL
    }
     getConfig() {
         mockedCommand "getConfig $@"
         case $1 in
             LFS_CI_uc_klocwork_project_name)         echo PS_LFS_DDAL ;;
             LFS_CI_uc_klocwork_port)                 echo 12345 ;;
             LFS_CI_uc_klocwork_hostname)             echo klocwork_hostname ;;
             LFS_CI_uc_klocwork_licence_port)         echo 54321 ;;
             LFS_CI_uc_klocwork_licence_host)         echo licence_hostname ;;
             LFS_CI_uc_klocwork_cmd_kwinject)         echo /path/to/bin/kwinject ;;
             LFS_CI_uc_klocwork_cmd_kwadmin)          echo /path/to/bin/kwadmin ;;
             LFS_CI_uc_klocwork_cmd_kwbuildproject)   echo /path/to/bin/kwbuildproject ;;
             LFS_CI_uc_klocwork_url)                  echo http://klocwork_hostname:12345/ ;;
             LFS_CI_uc_klocwork_template)             echo kw_template ;;
             LFS_CI_uc_klocwork_tables)               echo kw_tables ;;
             LFS_CI_uc_klocwork_architectures)        echo arm powerpc mips i386 x64 ;;
             LFS_CI_uc_klocwork_report_python_script) echo http://svn/path/to/script.py ;;
             LFS_CI_uc_klocwork_python_home)          echo /path/to/python/home ;;
         esac
     }

    svnExport() {
        mockedCommand "svnExport $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UNITTEST_COMMAND}
}

tearDown() {
    rm -rf ${UNITTEST_COMMAND}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

testUsecaseKlocwork_part1() {
    # export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
    export WORKSPACE=$(createTempDirectory)
    export BUILD_ID=1234

    # assertTrue "ci_job_klocwork_build"
    ci_job_klocwork_build

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_klocwork_port
mustHaveValue 12345 klocwork port
getConfig LFS_CI_uc_klocwork_hostname
mustHaveValue klocwork_hostname klocwork host
getConfig LFS_CI_uc_klocwork_licence_port
mustHaveValue 54321 klocwork licence port
getConfig LFS_CI_uc_klocwork_licence_host
mustHaveValue licence_hostname klocwork licence host
getTargetBoardName
mustHaveValue PS_LFS_DDAL klocwork project
getConfig LFS_CI_uc_klocwork_cmd_kwinject
mustHaveValue /path/to/bin/kwinject klocwork cmd kwinject
getConfig LFS_CI_uc_klocwork_cmd_kwadmin
mustHaveValue /path/to/bin/kwadmin klocwork cmd kwadmin
getConfig LFS_CI_uc_klocwork_cmd_kwbuildproject
mustHaveValue /path/to/bin/kwbuildproject klocwork build project
getConfig LFS_CI_uc_klocwork_url
mustHaveValue --url http://klocwork_hostname:12345/ klocwork url
getConfig LFS_CI_uc_klocwork_template
mustHaveValue kw_template klocwork template
getConfig LFS_CI_uc_klocwork_tables
mustHaveValue kw_tables klocwork tables
mustHaveValue ${WORKSPACE}/workspace klocwork psroot
getConfig LFS_CI_uc_klocwork_architectures
mustHaveValue arm powerpc mips i386 x64 architectures
getConfig LFS_CI_uc_klocwork_report_python_script
mustHaveValue http://svn/path/to/script.py python report script
getConfig LFS_CI_uc_klocwork_python_home
mustHaveValue /path/to/python/home python home
createOrUpdateWorkspace --allowUpdate
execute cd ${WORKSPACE}/workspace
execute /path/to/bin/kwinject -P armgcc=gnu -P armg++=gnu -P powerpcgcc=gnu -P powerpcg++=gnu -P mipsgcc=gnu -P mipsg++=gnu -P i386gcc=gnu -P i386g++=gnu -P x64gcc=gnu -P x64g++=gnu --ignore-files **/*build/**/*,**/*build/* --variable kwpsroot=${WORKSPACE}/workspace -o kw_template bash -c ${WORKSPACE}/workspace/bldtools/bld-buildtools-common/results/bin/build NOAUTOBUILD=1 -C src-rfs fct; ${WORKSPACE}/workspace/bldtools/bld-buildtools-common/results/bin/build NOAUTOBUILD=1 -C src-fsmddal fct
execute /path/to/bin/kwadmin --url http://klocwork_hostname:12345/ import-config PS_LFS_DDAL kw_template
execute /path/to/bin/kwbuildproject --url http://klocwork_hostname:12345//PS_LFS_DDAL --license-host licence_hostname --license-port 54321 --replace-path ${WORKSPACE}/workspace/src-=src- --buildspec-variable kwpsroot=${WORKSPACE}/workspace --incremental --project PS_LFS_DDAL --tables-directory kw_tables kw_template
getConfig LFS_CI_uc_klocwork_can_upload_builds
execute /path/to/bin/kwadmin --url http://klocwork_hostname:12345/ load PS_LFS_DDAL kw_tables --name build_ci_1234
svnExport http://svn/path/to/script.py
execute /path/to/python/home/bin/python getreport.py klocwork_hostname 12345 PS_LFS_DDAL LAST
getConfig LFS_CI_uc_klocwork_can_delete_builds
createTempFile
execute -n /path/to/bin/kwadmin --url http://klocwork_hostname:12345/ list-builds PS_LFS_DDAL
execute sed -ine /^\(Bld\|Build\|Rev\|build_ci\)/ {17,$ p} /tmp/file
createTempFile
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

}

source lib/shunit2

exit 0
