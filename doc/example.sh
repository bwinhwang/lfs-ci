#!/bin/bash

# identifier of the source code. git is generating the id.
# this is also the protection of multiple include of the module.
# it also handles the order / dependencies of including the modules.
LFS_CI_SOURCE_example='$Id$'

# include of other modules,
[[ -z ${LFS_CI_SOURCE_common}  ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_logging} ]] && source ${LFS_CI_ROOT}/lib/logging.sh

## @fn      demoFuntion( $param )
#  @brief   this is a brief description of the function within one line
#  @warning please use this function with care
#  @details here we have a full description of the function.
#  @todo    some parts are not implemented yet.
#  @param   {parameter1}    the first parameter of the function
#  @param   {parameter2}    the second parameter of the function
#  @param   <none> 
#  @return  <none>
#  @return  the return value of the function
#  @return  1 if something happens, 0 otherwise
#  @throws  an error, if something happens badly
demoFuntion() {

    # list all envirionment variables, which are required by this function
    # envirionment variables are written in UPPER CASE
    requiredParameters WORKSPACE LABEL

    # define the local variables, which the function is using internally
    # local variables are defined as local and are written in camelCase
    local parameter1=${1}
    local parameter2=${2}

    # ensures, that there is a parameter1, which has a non empty value.
    # if the value is empty, it will be raise an error. 
    mustHaveValue "${parameter1}" "parameter 1"

    # getting an value from the configuration file
    local canWeDoSomeStuff=$(getConfig LFS_CI_uc_example_can_we_do_some_stuff)

    if [[ ! ${canWeDoSomeStuff} ]] ; then
        warning "we can not do some stuff, cause it is disabled in config"
        return
    fi

    # do some stuff here
    local workspace=$(getWorkspaceName)
    doSomeStuff ${workspace}

    return 0
}


