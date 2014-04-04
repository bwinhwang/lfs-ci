#!/bin/bash

## @fn      execute( command )
#  @brief   executes the given command in a shell
#  @details this method executes a given command in the same shell. The
#           output (stderr and stdout) will be written into the logfile.
#           The output is not shown on the console.
#           If there is an error (exit code != 0) in the command, an
#           error will be raised and logged. The scripting ends here!
#  @todo    «description of incomplete business»
#  @param   {command}    a command string
#  @return  <none>
#  @throws  raise an error, if the command exits with an exit code != 0
execute() {
    local command=$@
    local output=$(createTempFile)

    trace "execute command: \"${command}\""

    ${command} >${output} 2>&1

    exitCode=$?
    trace "exit code of \"${command}\" was ${exitCode}"

    rawDebug ${output}

    if [[ ${exitCode} -gt 0 ]] ; then
        rawOutput ${output}
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
    execute ssh ${jenkinsMasterServerHostName} ${command}
    return
}

runOnMaster() {
    local command=$@
    trace "running command on server: ssh ${jenkinsMasterServerHostName} ${command}"
    ssh ${jenkinsMasterServerHostName} ${command}
    return $?
}

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

    # workaround for screen / TERMCAP
    unset TERM
    unset TERMCAP
    keys=`(set -o posix ; set ) | grep = | grep -v '^!' | awk -F= '{ if ( $0 ~ /\\\\$/ ) 
                                                                        a=1; 
                                                                     else 
                                                                        print $1; }' `
    for key in ${keys}; do
        case ${key} in
            BASH*) : ;; # can not unset 
            UID|EUID)  : ;;
            SHELLOPTS) : ;;
            PPID) : ;;
            PATH|HOME|USER|HOSTNAME) : ;;
            LFS_CI_ROOT) : ;;
            LFS_CI_SHARE_MIRROR) : ;;
            LFS_CI*) : ;;
            CI_LOGGING_LOGFILENAME) : ;;
            CI_*) : ;;
            WORKSPACE) : ;;
            SVN_REVISION) : ;;
            UPSTREAM_BUILD) : ;;
            UPSTREAM_PROJECT) : ;;
            BUILD_*) : ;;
            NODE_LABELS) : ;;
            *) 
                trace "unsetting environment variable \"${key}\" with value \"${!key}\"" 
                unset ${key} 
            ;;
        esac
    done

    return
}

