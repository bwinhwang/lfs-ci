#!/bin/bash
# ---------------------------------------------------------------------
# LFS CI scripting 
# (c) 2014,2015 Nokia 
# ---------------------------------------------------------------------
# contact: lfs-ci-dev@mlist.intra.nsn-net.net
# ---------------------------------------------------------------------
#
# start skript for all LFS CI jenkins jobs.
#

if [[ -z "${LFS_CI_ROOT}" ]] ; then
    export LFS_CI_ROOT=${PWD}
fi
if [[ ! -z "${1}" ]] ; then
    export JOB_NAME=$1
    shift
fi

source ${LFS_CI_ROOT}/lib/startup.sh

prepareStartup 

# new part here
# each job defines a set of environment variables, which defines
# the actions of jobs.
# * LFS_CI_GLOBAL_USECASE
# * LFS_CI_GLOBAL_BRANCH
# * LFS_CI_GLOBAL_PRODUCT
# * LFS_CI_GLOBAL_BUILD_CONFIG
# ...
if [[ ${LFS_CI_GLOBAL_USECASE} ]] ; then
    info "running usecase ${LFS_CI_GLOBAL_USECASE}"

    sourceFile=$(getConfig LFS_CI_usecase_file)
    mustExistFile ${LFS_CI_ROOT}/lib/${sourceFile}

    source ${LFS_CI_ROOT}/lib/${sourceFile}

    usecase_${LFS_CI_GLOBAL_USECASE}
    exit 0
fi

# first dispatcher, calling the correct script or function
case "${JOB_NAME}" in
    *_CI_*_Build) 
        source ${LFS_CI_ROOT}/lib/uc_build.sh
        ci_job_build_version || exit 1 
    ;;
    *_CI_*_Build_*) 
        source ${LFS_CI_ROOT}/lib/uc_build.sh
        ci_job_build || exit 1 
    ;;
    LFS_CI_*_KlocworkBuild_*) 
        source ${LFS_CI_ROOT}/lib/uc_klocwork.sh
        ci_job_klocwork_build || exit 1 
    ;;
    LTK_CI_*_Package_*) 
        source ${LFS_CI_ROOT}/lib/uc_ltk_package.sh
        ci_job_package || exit 1 
    ;;
    LFS_CI_*_Package_*) 
        source ${LFS_CI_ROOT}/lib/uc_lfs_package.sh
        ci_job_package || exit 1 
    ;;
    UBOOT_CI_*_Package_*) 
        source ${LFS_CI_ROOT}/lib/uc_uboot_package.sh
        ci_job_package || exit 1 
    ;;
    *_CI_*_ECL_*|*_CI_*_Write_ECL_*)
        source ${LFS_CI_ROOT}/lib/uc_ecl.sh
        ci_job_ecl    || exit 1 
    ;;
    *_-_postProductionTest)
        source ${LFS_CI_ROOT}/lib/uc_test_on_target.sh
        ci_job_test_on_target || exit 1 
    ;;
    *_CI_*_Test*metrics)
        source ${LFS_CI_ROOT}/lib/uc_collect_metrics.sh
        ci_job_test_collect_metrics || exit 1 
    ;;
    *_CI_*_Unittest*ddal)
        source ${LFS_CI_ROOT}/lib/uc_test_unittest_ddal.sh
        ci_job_test_unittest_ddal || exit 1 
    ;;
    *_CI_*_Unittest*)
        source ${LFS_CI_ROOT}/lib/uc_test_unittest.sh
        ci_job_test_unittest || exit 1 
    ;;
    *_CI_*_Test*)
        source ${LFS_CI_ROOT}/lib/uc_test.sh
        ci_job_test    || exit 1 
    ;;
    LFS_Post_*_TestBuildsystem_*)
        source ${LFS_CI_ROOT}/lib/uc_test_buildsystem.sh
        ci_job_test_buildsystem || exit 1 
    ;;
    Test-*_archiveLogs)
        source ${LFS_CI_ROOT}/lib/uc_test_on_target.sh
        uc_job_test_on_target_archive_logs || exit 1 
    ;;
    Test-*)
        source ${LFS_CI_ROOT}/lib/uc_test_on_target.sh
        ci_job_test_on_target || exit 1 
    ;;
    Admin_*)
        source ${LFS_CI_ROOT}/lib/uc_admin.sh
        ci_job_admin   || exit 1 
    ;;
    LFS_Prod_*_Releasing_*|UBOOT_Prod_*_Releasing_*|LTK_Prod_*_Releasing_*)
        source ${LFS_CI_ROOT}/lib/uc_release.sh
        ci_job_release || exit 1 
    ;;
    *)
        fatal "don't know what I shall do for job \"${JOB_NAME}\"" 
    ;;
esac

exit 0
