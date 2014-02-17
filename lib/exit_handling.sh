#!/bin/bash


CI_EXIT_HANDLER_METHODS=''

# print stacktrace using trace logging. this enables trace log output
# automatically

exit_add() {
	CI_EXIT_HANDLER_METHODS="$1 $CI_EXIT_HANDLER_METHODS"
	trace "exit: methods now '$CI_EXIT_HANDLER_METHODS'"
}

# exit handler registered to traps
#   $1: log message to print
#   $2: != 0 => print stacktrace
#   $3: exit code
exit_handler() {
    trace "now calling exit methods: $1"
    trace "disabling signal handler for ERR, EXIT, SIGTERM and SIGINT"

	trap - ERR EXIT SIGTERM SIGINT

	[ $2 -ne 0 ] && trace "$(_stackTrace)"

	for m in ${CI_EXIT_HANDLER_METHODS}; do
		$m
	done

    # hardcoded closing the logfile gracefully
    stopLogfile

	exit $3
} 

trap "exit_handler 'normal exit' 0 0" EXIT
trap "exit_handler 'error occured' 1 1" ERR
trap "exit_handler 'terminated' 1 2" SIGTERM
trap "exit_handler 'interrupted' 1 3" SIGINT

