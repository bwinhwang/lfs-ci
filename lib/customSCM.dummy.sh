#!/bin/bash

## @fn      actionCompare()
#  @brief   trigger a build every time
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
#  @param   <none>
#  @return  1 if if a build is not required, 0 otherwise
actionCompare() {
        exit 0
}


## @fn      actionCheckout()
#  @brief   action which is called by custom scm jenkins plugin to create or update a workspace and create the changelog
#  @details the create workspace task is empty here. We just calculate the changelog
#  @param   <none>
#  @return  <none>
actionCheckout() {
    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"
    return
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details
#  @param   <none>
#  @return  <none>
actionCalculate() {
    echo $(date) ${USER} > ${REVISION_STATE_FILE}
    return 
}
