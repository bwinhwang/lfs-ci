#!/bin/bash
#
# start skript for jenkins.
#

TMP=$(dirname $0)
export LFS_CI_PATH="$(readlink -f ${TMP}/..)"
export PATH=${PATH}:${LFS_CI_PATH}/bin

source ${LFS_CI_PATH}/lib/logging.sh
source ${LFS_CI_PATH}/lib/commands.sh
source ${LFS_CI_PATH}/lib/build.sh
source ${LFS_CI_PATH}/lib/common.sh
source ${LFS_CI_PATH}/lib/config.sh

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

JENKINS_JOB_NAME="$1"
export JENKINS_JOB_NAME 

JENKINS_SVN_REVISION=${SVN_REVISION}
export JENKINS_SVN_REVISION

showAllEnvironmentVariables

info "starting jenkins job \"${JENKINS_JOB_NAME}\" on ${HOSTNAME} as ${USER}"

# first dispatcher, calling the correct script or function
case "${JENKINS_JOB_NAME}" in
    LFS_CI_*_Build)   ci_job_package || exit 1 ;;
    LFS_CI_*_Build_*) ci_job_build   || exit 1 ;;
    *)

        # legacy call for the old scripting...
        if [[ -x "${JENKINS_JOB_NAME}" ]] ; then

            info "executing legacy script \"${JENKINS_JOB_NAME}\""

            execute ${JENKINS_JOB_NAME} \
                || exit 1
        else
            error "don't know what I shall do for job \"${JENKINS_JOB_NAME}\"" 
            exit 1
        fi

    ;;
esac

exit 0
