#!/bin/bash
#
# start skript for jenkins.
#

TMP=$(dirname $0)
export CI_LIB_PATH="$(readlink -f ${TMP}/..)"
PATH=$PATH:$CI_LIB_PATH/bin

source ${CI_LIB_PATH}/lib/ci_logging.sh
source ${CI_LIB_PATH}/lib/commands.sh
source ${CI_LIB_PATH}/lib/build.sh
source ${CI_LIB_PATH}/lib/common.sh

cleanupEnvironmentVariables

export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

JENKINS_JOB_NAME="$1"
export JENKINS_JOB_NAME

showAllEnvironmentVariables

info "starting jenkins job \"${JENKINS_JOB_NAME}\" on ${HOSTNAME} as ${USER}"

# start the logfile
startLogfile
# and end it, if the script exited in some way
exit_add stopLogfile

# first dispatcher, calling the correct script
case "${JENKINS_JOB_NAME}" in
    *build*)
        ci_job_build \
            || exit 1
    ;;
    *)

        # legacy call for the old scripting...
        if [[ -x "${JENKINS_JOB_NAME}" ]] ; then

            info "executing legacy script \"${JENKINS_JOB_NAME}\""

            call ${JENKINS_JOB_NAME} \
                || exit 1
        else
            error "don't know what I shall do for job \"${JENKINS_JOB_NAME}\"" 
            exit 1
        fi

    ;;
esac
exit 0
