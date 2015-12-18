#!/bin/bash
## @file  exit_handling.sh
#  @brief handling of the exit trap
#
#  You can add a function, which should be executed when the script exits.
#
#  e.g.: exit_add cleanupTempFiles
# 
#  This means, that cleanupTempFiles will be executed, when the scripts end.
#  You can use this to do actions, which should be executed, no mether if
#  the script is failing or not.

LFS_CI_SOURCE_exit_handling='$Id$'

export CI_EXIT_HANDLER_METHODS=''

# print stacktrace using trace logging. this enables trace log output
# automatically

## @fn      exit_add()
#  @brief   register a function to be executed in the exit handler
#  @param   {functionName}    name of the function
#  @return  <none>
exit_add() {
    local functionName=$1
	CI_EXIT_HANDLER_METHODS=" ${functionName} ${CI_EXIT_HANDLER_METHODS}"
    trace "exit handler: added ${functionName}: exit functions are now '${CI_EXIT_HANDLER_METHODS}'"
    return
}

## @fn      exit_remove()
#  @brief   remove a registered function, which should be executed in the exit handler
#  @param   {functionName}     name of the function
#  @return  <none>
exit_remove() {
    local functionName=$1
    CI_EXIT_HANDLER_METHODS="${CI_EXIT_HANDLER_METHODS/ ${functionName}}"
    trace "exit handler: removed ${functionName}: exit functions are now '${CI_EXIT_HANDLER_METHODS}'"
    return
}

## @fn      exit_handler()
#  @brief   exit handler, run the registered traps
#  @param   {msg}               log message to print
#  @param   {showStacktrace}    should the stacktrace be printed
#  @param   {exitCode}          exit code
#  @return  exit code
exit_handler() {
    local rc=$?
    trace "now calling exit methods: $1 $2 $rc"
    trace "disabling signal handler for ERR, EXIT, SIGTERM and SIGINT"
    trace "exit methods are ${CI_EXIT_HANDLER_METHODS}"

	trap - ERR EXIT SIGTERM SIGINT

	[[ $2    -ne 0 ]] && trace "$(_stackTrace)"
	[[ ${rc} -ne 0 ]] && trace "$(_stackTrace)"

	for m in ${CI_EXIT_HANDLER_METHODS}; do
        # remark: it is possible to give parameters to the exit funktion
        # this parameters are separated via :
        # e.g.: exitFuntion:parameter1:parameter2
		${m//:/} ${rc}
	done

	exit ${rc:-3}
} 

trap "exit_handler 'normal exit $?' 0 0" EXIT
trap "exit_handler 'error occured'  1 1" ERR
trap "exit_handler 'terminated'     1 2" SIGTERM
trap "exit_handler 'interrupted'    1 3" SIGINT

