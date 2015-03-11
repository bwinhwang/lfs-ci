#!/bin/bash
## @file    commands.sh
#  @brief   handling of executing commands and handle the errors in a proper way
#  @details The main function here is the execute function. This function should
#           help the developer to execute a command in the correct way including
#           logging of the command and the proper error handling.

[[ -z ${LFS_CI_SOURCE_common}  ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_logging} ]] && source ${LFS_CI_ROOT}/lib/logging.sh

LFS_CI_SOURCE_commands='$Id$'

## @fn      execute()
#  @brief   executes the given command in a shell
#  @details this method executes a given command in the same shell. The
#           output (stderr and stdout) will be written into the logfile.
#           The output is not shown on the console.
#           If there is an error (exit code != 0) in the command, an
#           error will be raised and logged. The scripting ends here!
#  @param   {opt}     -n flag - turn the default redirection of stdout off
#  @param   {opt}     -i flag - ignore the error code from the command and continue
#  @param   {opt}     -r parameter - retry the command, if it failed x times. After this it will fail.
#  @param   {opt}     -l parameter - write the output of the command into the given log file, the log must exists before.
#  @param   {command} a command string
#  @return  <none>
#  @throws  raise an error, if the command exits with an exit code != 0
execute() {
    debug "execute $@"
    local noRedirect=
    local retryCount=1
    local ignoreError=
    local logfile=${LFS_CI_LAST_EXECUTE_LOGFILE}

    # Note: we are not using getopt, because we have problems with parsing
    # the parameters from the command. We don't want that.
    while [[ $# -gt 0 ]]
    do
        case $1 in
            -n|--noredirect)   noRedirect=1  ;;
            -i|--ignore-error) ignoreError=1 ;;
            -r|--retry)        retryCount=$2 ; shift ;;
            -l|--logfile)      logfile=$2    ; shift ;;
            --)                shift ; break ;;
            (-*)               fatal "unrecognized option $1" ;;
            *)                 break ;;
        esac
        shift;
    done

    local command="$@"
    local exitCode=1
    local output=

    # in cause of an error and the user requested it, we can rerun the
    # command serveral times with some delay.
    # the retryCount can be choosen by the user
    while [[ ${retryCount} -gt 0 && ${exitCode} -ne 0 ]] ; do
        retryCount=$((retryCount - 1))
        trace "execute command: \"${@}\""
        if [[ ${noRedirect} ]] ; then
            # in case that the user forgot to redirect stderr to stdout, we are doing it for him...
            # this is called real service!!
            "${@}" 2>&1 
            exitCode=${?}
        else
            output=$(createTempFile)
            "${@}" >${output} 2>&1
            exitCode=${?}
            rawDebug ${output}
        fi

        trace "exit code of \"${command}\" was ${exitCode}"

        # fucking stupid workaround to get the logfile for the command outside
        # of the function.....
        # TODO: demx2fk3 2015-02-10 find a better way to do this.
        if [[ -e ${logfile} ]] ; then
            cat ${output} > ${logfile}
        fi

        # in the last loop, don't wait, just exist
        if [[ ${retryCount} -gt 0 && ${exitCode} -gt 0 ]] ; then
            local randomSeconds=$((RANDOM % 20))
            trace "waiting ${randomSeconds} seconds for retry execution (try ${retryCount}"
            sleep ${randomSeconds}
        fi
    done

    if [[ ${exitCode} -gt 0 ]] ; then
        [[ -e ${output} ]] && rawOutput ${output}
        if [[ -z ${ignoreError} ]] ; then
            error "error occoured in \"${command}\""
            exit ${exitCode}
        else
            warning "error occoured in \"${command}\""
        fi
    fi

    trace "normal return of execute method"

    return ${exitCode}
}

lastExecuteLogFile() {
    echo ${LFS_CI_LAST_EXECUTE_LOGFILE}
    return
}

## @fn      executeOnMaster()
#  @brief   executes the given command on the master servers
#  @warning the output will be stored in the logfile and will not given back to the user.
#           if there is an error, the programm will raise an error
#  @param   {command}    command string - no quoting required
#  @return  <none>
#  @throws  raise an error, if command fails
executeOnMaster() {
    local command=$@
    # TODO: demx2fk3 2015-03-09 FIXME SSH_LOAD replace this with other server
    local server=$(getConfig jenkinsMasterServerHostName)

    execute -r 10 ssh ${server} ${command}
    return
}

## @fn      runOnMaster()
#  @brief   ron a command on the master server and show the results.
#  @param   {command}    command string
#  @return  exit code of the command
runOnMaster() {
    local command=$@
    local server=$(getConfig jenkinsMasterServerHostName)
    mustHaveValue "${server}" "server name"
    trace "running command on server: ssh ${server} ${command}"
    execute -n -i ssh ${server} ${command}
    return $?
}

## @fn      showAllEnvironmentVariables()
#  @brief   show all environment variables, which are available at the moment
#  @param   <none>
#  @return  <none>
showAllEnvironmentVariables() {
    execute printenv        
    return
}
