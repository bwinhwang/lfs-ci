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

#     getConfig() {
#         mockedCommand "getConfig $@"
#         case $1 in
#             LFS_CI_uc_klocwork_project_name)         echo PS_LFS_DDAL ;;
#             LFS_CI_uc_klocwork_port)                 echo 12345 ;;
#             LFS_CI_uc_klocwork_hostname)             echo klocwork_hostname ;;
#             LFS_CI_uc_klocwork_licence_port)         echo 54321 ;;
#             LFS_CI_uc_klocwork_licence_host)         echo licence_hostname ;;
#             LFS_CI_uc_klocwork_cmd_kwinject)         echo /path/to/bin/kwinject ;;
#             LFS_CI_uc_klocwork_cmd_kwadmin)          echo /path/to/bin/kwadmin ;;
#             LFS_CI_uc_klocwork_cmd_kwbuildproject)   echo /path/to/bin/kwbuildproject ;;
#             LFS_CI_uc_klocwork_url)                  echo http://klocwork_hostname:12345/ ;;
#             LFS_CI_uc_klocwork_template)             echo kw_template ;;
#             LFS_CI_uc_klocwork_tables)               echo kw_tables ;;
#             LFS_CI_uc_klocwork_architectures)        echo arm powerpc mips i386 x64 ;;
#             LFS_CI_uc_klocwork_report_python_script) echo http://svn/path/to/script.py ;;
#             LFS_CI_uc_klocwork_python_home)          echo /path/to/python/home ;;
#         esac
#     }

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
    cat ${UNITTEST_COMMAND}

#     local expect=$(createTempFile)
#     cat <<EOF > ${expect}
# EOF
#     assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

}

source lib/shunit2

exit 0
