#!/bin/bash

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
	CI_EXIT_HANDLER_METHODS="${functionName} ${CI_EXIT_HANDLER_METHODS}"
	trace "exit: methods now '${CI_EXIT_HANDLER_METHODS}'"
    return
}

## @fn      exit_handler()
#  @brief   exit handler, run the registered traps
#  @details TODO: demx2fk3 2014-12-16 
#  @param   {msg}               log message to print
#  @param   {showStacktrace}    should the stacktrace be printed
#  @param   {exitCode}          exit code
#  @param   <none>
#  @return  exit code
exit_handler() {
    local rc=$?
    trace "now calling exit methods: $1 $2 $rc"
    trace "disabling signal handler for ERR, EXIT, SIGTERM and SIGINT"
    trace "exit methods are ${CI_EXIT_HANDLER_METHODS}"

	trap - ERR EXIT SIGTERM SIGINT

	[ $2    -ne 0 ] && trace "$(_stackTrace)"
	[ ${rc} -ne 0 ] && trace "$(_stackTrace)"

	for m in ${CI_EXIT_HANDLER_METHODS}; do
		${m} ${rc}
	done

	exit ${rc:-3}
} 

trap "exit_handler 'normal exit $?' 0 0" EXIT
trap "exit_handler 'error occured'  1 1" ERR
trap "exit_handler 'terminated'     1 2" SIGTERM
trap "exit_handler 'interrupted'    1 3" SIGINT

