#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common} ]] && source ${LFS_CI_ROOT}/lib/common.sh
LFS_CI_SOURCE_commands='$Id$'

# TODO: demx2fk3 2014-10-27 source logging.sh is missing

## @fn      execute( command )
#  @brief   executes the given command in a shell
#  @details this method executes a given command in the same shell. The
#           output (stderr and stdout) will be written into the logfile.
#           The output is not shown on the console.
#           If there is an error (exit code != 0) in the command, an
#           error will be raised and logged. The scripting ends here!
#  @param   {opt}    -n flag - turn the default redirection of stdout off
#  @param   {command}    a command string
#  @return  <none>
#  @throws  raise an error, if the command exits with an exit code != 0
execute() {
    debug "execute $@"
    local opt=$1
    local noRedirect=
    local retryCount=1
    if [[ ${opt} = "-n" ]] ; then
        # we found an -n as the first parameter, so the user
        # want to redirect the stuff by himself.
        trace "user requested own redirection via -n"
        shift
        noRedirect=1
    fi
    opt=$1
    if [[ ${opt} = "-r" ]] ; then
        shift
        retryCount=$1
        shift
        trace "user requested reexecution via -r ${retryCount}"
    fi
 
    local command=$@
    local exitCode=1
    local output=

    # in cause of an error and the user requested it, we can rerun the
    # command serveral times with some delay.
    # the retryCount can be choosen by the user
    while [[ ${retryCount} -gt 0 && ${exitCode} -ne 0 ]] ; do
        retryCount=$((retryCount - 1))
        trace "execute command: \"${command}\""
        if [[ ${noRedirect} ]] ; then
            # in case that the user forgot to redirect stderr to stdout, we are doing it for him...
            # this is called real service!!
            ${command} 2>&1 
            exitCode=$?
        else
            output=$(createTempFile)
            ${command} >${output} 2>&1
            exitCode=$?
            rawDebug ${output}
        fi

        trace "exit code of \"${command}\" was ${exitCode}"

        # in the last loop, don't wait, just exist
        if [[ ${retryCount} -gt 0 && ${exitCode} -gt 0 ]] ; then
            local randomSeconds=$((RANDOM % 20))
            trace "waiting ${randomSeconds} seconds for retry execution (try ${retryCount}"
            sleep ${randomSeconds}
        fi
    done

    if [[ ${exitCode} -gt 0 ]] ; then
        [[ -e ${output} ]] && rawOutput ${output}
        error "error occoured in \"${command}\""
        exit ${exitCode}
    fi

    return
}

## @fn      executeOnMaster( command )
#  @brief   executes the given command on the master servers
#  @warning the output will be stored in the logfile and will not given back to the user.
#           if there is an error, the programm will raise an error
#  @param   {command}    command string - no quoting required
#  @return  <none>
#  @throws  raise an error, if command fails
executeOnMaster() {
    local command=$@
    local server=$(getConfig jenkinsMasterServerHostName)

    execute ssh ${server} ${command}
    return
}

## @fn      runOnMaster( command )
#  @brief   ron a command on the master server and show the results.
#  @param   {command}    command string
#  @return  exit code of the command
runOnMaster() {
    local command=$@
    local server=$(getConfig jenkinsMasterServerHostName)
    trace "running command on server: ssh ${server} ${command}"
    ssh ${server} ${command}
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

## @fn      cleanupEnvironmentVariables()
#  @brief   cleanup the environment variables to have a clean env.
#  @todo    there are some problems here.. this is not working as expected.. 
#  @param   <none>
#  @return  <none>
cleanupEnvironmentVariables() {
    local key=""

    # TODO: demx2fk3 2014-06-16 not in use!!

    # workaround for screen / TERMCAP
    unset TERM
    unset TERMCAP
    keys=`(set -o posix ; set ) | grep = | grep -v '^!' | awk -F= '{ if ( $0 ~ /\\\\$/ ) 
                                                                        a=1; 
                                                                     else 
                                                                        print $1; }' `
    for key in ${keys}; do
        case ${key} in
            BASH*)                   : ;; #  can not unset
            UID|EUID)                : ;;
            SHELLOPTS)               : ;;
            PPID)                    : ;;
            PATH|HOME|USER|HOSTNAME) : ;;
            LFS_CI_ROOT)             : ;;
            LFS_CI_SHARE_MIRROR)     : ;;
            LFS_CI*)                 : ;;
            CI_LOGGING_LOGFILENAME)  : ;;
            CI_*)                    : ;;
            WORKSPACE)               : ;;
            SVN_REVISION)            : ;;
            UPSTREAM_BUILD)          : ;;
            UPSTREAM_PROJECT)        : ;;
            BUILD_*)                 : ;;
            NODE_LABELS)             : ;;
            *) 
                trace "unsetting environment variable \"${key}\" with value \"${!key}\"" 
                unset ${key} 
            ;;
        esac
    done

    return
}

