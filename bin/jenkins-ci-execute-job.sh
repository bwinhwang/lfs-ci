#!/bin/bash
#
# start skript for jenkins.
#

source lib/ci_logging.sh
source lib/commands.sh
source lib/build.sh

cleanupEnvironmentVariables

JENKINS_JOB_NAME="$1"
export JENKINS_JOB_NAME

info "starting jenkins job \"${JENKINS_JOB_NAME}\" on ${HOSTNAME} as ${USER}"

# start the logfile
startLogfile
# and end it, if the script exited in some way
exit_add stopLogfile

# first dispatcher, calling the correct script
case "${JENKINS_JOB_NAME}" in
    *Build*)
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
            error "don't know what I shall do for job ${JENKINS_JOB_NAME}" 
            exit 1
        fi

    ;;
esac
exit 0
