#!/bin/bash
#
# start skript for jenkins.
#

# TMP=$(dirname $0)
# export LFS_CI_PATH="$(readlink -f ${TMP}/..)"
export PATH=${PATH}:${LFS_CI_ROOT}/bin

source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/commands.sh
source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/config.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh

# load the properties from the custom SCM jenkins plugin
if [[ -f ${WORKSPACE}/.properties ]] ; then
    source ${WORKSPACE}/.properties
fi

# start the logfile
startLogfile
# and end it, if the script exited in some way
exit_add stopLogfile

# TODO: demx2fk3 2014-03-31 fixme
# cleanupEnvironmentVariables

# for better debugging
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
export PS4

JENKINS_SVN_REVISION=${SVN_REVISION}
export JENKINS_SVN_REVISION

showAllEnvironmentVariables

info "starting jenkins job \"${JOB_NAME}\" on ${HOSTNAME} as ${USER}"

# first dispatcher, calling the correct script or function
case "${JOB_NAME}" in
    LFS_CI_*_Build_*) 
        source ${LFS_CI_ROOT}/lib/uc_build.sh
        ci_job_build   || exit 1 
    ;;
    LFS_CI_*_Package_*) 
        source ${LFS_CI_ROOT}/lib/uc_package.sh
        ci_job_package || exit 1 
    ;;
    LFS_CI_*_Test_*)
        source ${LFS_CI_ROOT}/lib/uc_test.sh
        ci_job_test    || exit 1 
    ;;
    LFS_CI_*_Admin_*)
        source ${LFS_CI_ROOT}/lib/uc_admin.sh
        ci_job_admin   || exit 1 
    ;;
    LFS_Prod_*_Releasing_*)
        source ${LFS_CI_ROOT}/lib/uc_release.sh
        ci_job_release   || exit 1 
    ;;
    *)

        # legacy call for the old scripting...
        if [[ -x "${JOB_NAME}" ]] ; then

            info "executing legacy script \"${JOB_NAME}\""

            execute ${JOB_NAME} \
                || exit 1
        else
            error "don't know what I shall do for job \"${JOB_NAME}\"" 
            exit 1
        fi

    ;;
esac

exit 0
