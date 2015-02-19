#!/bin/bash
# ---------------------------------------------------------------------
# LFS CI scripting 
# (c) 2014,2015 Nokia 
# ---------------------------------------------------------------------
# contact: lfs-ci-dev@mlist.intra.nsn-net.net
# ---------------------------------------------------------------------
#
# start skript for jenkins jobs.
#

if [[ -z "${LFS_CI_ROOT}" ]] ; then
    export LFS_CI_ROOT=${PWD}
fi

export PATH=${LFS_CI_ROOT}/bin:${PATH}

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/commands.sh
source ${LFS_CI_ROOT}/lib/config.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh
source ${LFS_CI_ROOT}/lib/subversion.sh

# load the properties from the custom SCM jenkins plugin
if [[ -f ${WORKSPACE}/.properties ]] ; then
    source ${WORKSPACE}/.properties
fi

# start the logfile
initTempDirectory
startLogfile
# archiveLogfile
# and end it, if the script exited in some way
exit_add stopLogfile

# TODO: demx2fk3 2014-03-31 FIXME
# cleanupEnvironmentVariables

# for better debugging
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
export PS4

LFS_CI_git_version=$(cd ${LFS_CI_ROOT} ; git describe)
debug "used lfs ci git version ${LFS_CI_git_version}"

# we do not want to have modifications in ${LFS_CI_ROOT}
#LFS_CI_git_local_modifications=$(cd ${LFS_CI_ROOT} ; git status --short | wc -l)
if [[ ${LFS_CI_git_local_modifications} -gt 0 ]] ; then
    fatal "the are local modifications in ${LFS_CI_ROOT}, which are not commited. "\
          "CI is rejecting such kind of working mode and refused to work until the modifications are commited."
fi

if [[ ! -z "${1}" ]] ; then
    export JOB_NAME=$1
    shift
fi

requiredParameters LFS_CI_ROOT JOB_NAME HOSTNAME USER 

showAllEnvironmentVariables

info "starting jenkins job \"${JOB_NAME}\" on ${HOSTNAME} as ${USER}"
if [[ "${UPSTREAM_PROJECT}" && "${UPSTREAM_BUILD}" ]] ; then
    info "upstream job ${UPSTREAM_PROJECT} / ${UPSTREAM_BUILD}"
fi

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

    # TODO: demx2fk3 2015-01-26 remove this hack
    Test-lcpa878)  ${LFS_CI_ROOT}/scripts/CLRC02_Test_Release_Candidate_LRC || exit 1 ;;
    Test-lcpa914)  ${LFS_CI_ROOT}/scripts/CLRC02_Test_Release_Candidate_LRC || exit 1 ;;
    Test-lcpa1093) ${LFS_CI_ROOT}/scripts/CLRC02_Test_Release_Candidate_LRC || exit 1 ;;
    Test-lcpa1105) ${LFS_CI_ROOT}/scripts/CLRC02_Test_Release_Candidate_LRC || exit 1 ;;
    Test-lcpa1239) ${LFS_CI_ROOT}/scripts/CLRC02_Test_Release_Candidate_LRC || exit 1 ;;
    
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
    *Test_-_postProductionTest)
        source ${LFS_CI_ROOT}/lib/uc_test_on_target.sh
        ci_job_test_on_target || exit 1 
    ;;
    *_CI_*_Test*metrics)
        source ${LFS_CI_ROOT}/lib/uc_collect_metrics.sh
        ci_job_test_collect_metrics || exit 1 
    ;;
    *_CI_*_Test*)
        source ${LFS_CI_ROOT}/lib/uc_test.sh
        ci_job_test    || exit 1 
    ;;
    *_CI_*_Unittest*)
        source ${LFS_CI_ROOT}/lib/uc_test_unittest_ddal.sh
        ci_job_test_unittest || exit 1 
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
        # legacy call for the old scripting...
        for pathName in ${LFS_CI_ROOT}/scripts/ ${LFS_CI_ROOT}/legacy
        do
            if [[ -x "$pathName/${JOB_NAME}" ]] ; then

                info "executing legacy script \"${JOB_NAME}\""

                $pathName/${JOB_NAME} $@ || exit 1
                break
            else
                # TODO: demx2fk3 2015-01-26 FIXME
                error "don't know what I shall do for job \"${JOB_NAME}\"" 
                exit 1
            fi
        done

    ;;
esac

exit 0
