#!/bin/bash

source test/common.sh
source lib/exit_handling.sh


oneTimeSetUp() {

    # we are testing the exit handler, so do not execute the exit handler
    # here in testing. not needed!
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    aFunction(){
        mockedCommand "aFunction $@"
        return
    }
    anotherFunction(){
        mockedCommand "anotherFunction $@"
        return
    }
    exit(){
        mockedCommand "exit $@"
        return 
    }
    _stackTrace() {
        mockedCommand "_stackTrace $@"
        return
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export CI_EXIT_HANDLER_METHODS=""

    trap "exit_handler 'normal exit $?' 0 0" EXIT
    trap "exit_handler 'error occured'  1 1" ERR
    trap "exit_handler 'terminated'     1 2" SIGTERM
    trap "exit_handler 'interrupted'    1 3" SIGINT

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    export CI_EXIT_HANDLER_METHODS=""
    return
}

test_exit_add1() {
    exit_add aFunction
    assertEquals " aFunction " "${CI_EXIT_HANDLER_METHODS}" 
    return
}

test_exit_add2() {
    exit_add aFunction
    exit_add anotherFunction
    assertEquals " anotherFunction  aFunction " "${CI_EXIT_HANDLER_METHODS}" 
    return
}

test_exit_remove1() {
    exit_add anotherFunction
    exit_remove anotherFunction
    assertEquals " " "${CI_EXIT_HANDLER_METHODS}" 
    return
}
test_exit_remove2() {
    exit_add aFunction
    exit_add anotherFunction
    exit_remove anotherFunction
    assertEquals "  aFunction " "${CI_EXIT_HANDLER_METHODS}" 
    return
}
test_exit_remove3() {
    exit_add aFunction
    exit_add anotherFunction
    exit_remove aFunction
    assertEquals " anotherFunction  " "${CI_EXIT_HANDLER_METHODS}" 
    return
}

test_exit_handler_normal_exit() {
    exit_add aFunction
    exit_add aFunction:param1
    exit_add anotherFunction
    exit_handler 'normal exit' 0 0

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
anotherFunction 0
aFunction param1 0
aFunction 0
exit 0
EOF
    assertExecutedCommands ${expect}

    return 0
}

test_exit_handler_error_occured() {
    exit_add aFunction
    exit_add aFunction:param1:param2
    exit_add anotherFunction
    false # we need an $? == 1 
    exit_handler 'error occured' 1 1

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_stackTrace 
anotherFunction 1
aFunction param1 param2 1
aFunction 1
exit 1
EOF
    assertExecutedCommands ${expect}

    return 0
}

test_exit_handler_terminated() {
    false # we need an $? == 1 
    exit_handler 'terminated' 1 2

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_stackTrace 
exit 1
EOF
    assertExecutedCommands ${expect}

    return 0
}

test_exit_handler_trap() {

    local expectBefore=$(createTempFile)
    cat <<EOF > ${expectBefore}
trap -- 'exit_handler '\''normal exit 0'\'' 0 0' EXIT
trap -- '' SIGHUP
trap -- 'exit_handler '\''interrupted'\''    1 3' SIGINT
trap -- 'exit_handler '\''terminated'\''     1 2' SIGTERM
EOF
    local expectAfter=$(createTempFile)
    cat <<EOF > ${expectAfter}
trap -- '' SIGHUP
EOF
    
    local got=$(createTempFile)
    trap > ${got}
    assertTrue "diff -rub ${expectBefore} ${got}"

    true
    exit_handler 'normal exit' 0 0

    expect=$(createTempFile)
    cat <<EOF > ${expect}
exit 0
EOF
    assertExecutedCommands ${expect}

    local got=$(createTempFile)
    trap > ${got}
    assertTrue "diff -rub ${expectAfter} ${got}"

    return 0
}
source lib/shunit2

exit 0
