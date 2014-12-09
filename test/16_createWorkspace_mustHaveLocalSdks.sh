#!/bin/bash

#  not ready yet
exit 0

source lib/common.sh
initTempDirectory

source lib/createWorkspace.sh

export UNITTEST_COMMAND=$(createTempFile)
export SHARE=$(createTempDirectory)

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
    mkdir -p ${SHARE}/build/home/path/to/baseline1
    mkdir -p ${SHARE}/build/home/path/to/baseline2
}

tearDown() {
    rm -rf ${UNITTEST_COMMAND}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    rm -rf ${SHARE}
    return
}

testUsecaseKlocwork_part1() {
    export WORKSPACE=$(createTempDirectory)
    export LFS_CI_SHARE_MIRROR=$(createTempDirectory)

    export BUILD_ID=1234

    mkdir -p ${WORKSPACE}/workspace/bld
    ln -sf ${SHARE}/build/home/path/to/baseline1 ${WORKSPACE}/workspace/bld/baseline1

    mustHaveLocalSdks

    # assertTrue "mustHaveLocalSdks"
    cat ${UNITTEST_COMMAND}

    find ${SHARE}
    find ${LFS_CI_SHARE_MIRROR}
    find ${WORKSPACE}
    ls -larR ${WORKSPACE}

#     local expect=$(createTempFile)
#     cat <<EOF > ${expect}
# EOF
#     assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

}

source lib/shunit2

exit 0
