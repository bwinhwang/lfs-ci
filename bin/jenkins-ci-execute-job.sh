#!/bin/bash
#
# start skript for jenkins.
#


TMP=$(dirname $0)
export LFS_CI_PATH="$(readlink -f ${TMP}/..)"
export PATH=${PATH}:${LFS_CI_PATH}/bin

source ${LFS_CI_PATH}/lib/ci_logging.sh
source ${LFS_CI_PATH}/lib/commands.sh
source ${LFS_CI_PATH}/lib/build.sh
source ${LFS_CI_PATH}/lib/common.sh
source ${LFS_CI_PATH}/lib/config.sh

if [[ -f ${WORKSPACE}/.properties ]] ; then
    source ${WORKSPACE}/.properties
fi

cleanupEnvironmentVariables
export CI_LOGGING_DURATION_OLD_DATE=0

# for better debugging
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
export PS4

JENKINS_JOB_NAME="$1"
export JENKINS_JOB_NAME 

JENKINS_SVN_REVISION=${SVN_REVISION}
export JENKINS_SVN_REVISION


showAllEnvironmentVariables

info "starting jenkins job \"${JENKINS_JOB_NAME}\" on ${HOSTNAME} as ${USER}"

# start the logfile
startLogfile
# and end it, if the script exited in some way
exit_add stopLogfile

# first dispatcher, calling the correct script
case "${JENKINS_JOB_NAME}" in
    LFS_CI_*_Build_*) ci_job_build   || exit 1 ;;
    LFS_CI_*_Build)   ci_job_package || exit 1 ;;
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
