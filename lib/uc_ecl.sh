#!/bin/bash

## @fn      updateEnvironmentControlList( workspace )
#  @brief   update the ECL file 
#  @details «full description»
#  @todo    add more doc
#  @param   <none>
#  @return  <none>
updateEnvironmentControlList() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local eclUrl=$(getConfig eclUrl)
    mustHaveValue ${eclUrl}


    # TODO: demx2fk3 2014-04-30 fixme
    local eclKeysToUpdate=$(getConfig asdf)
    mustHaveValue "${eclKeysToUpdate}"

    info "checkout ECL from ${eclUrl}"
    svnCheckout ${eclUrl} ${workspace}
    mustHaveWritableFile ${workspace}/ECL

    for eclKey in ${eclKeysToUpdate} ; do

        local eclValue=$(getEclValue ${eclKey})
        mustHaveValue "${eclKey}"

        info "update ecl key ${eclKey} with value ${eclValue}"
        execute perl -pi -e "s:^${eclKey}=.*:${eclValue}=${value}:" ECL

    done

    svnDiff ${workspace}/ECL

    # TODO: demx2fk3 2014-05-05 not fully implemented

    return
}

## @fn      getEclValue(  )
#  @brief   get the Value for the ECL for a specified key
#  @todo    implement this
#  @param   {eclKey}    name of the key from ECL
#  @return  value for the ecl key
getEclValue() {
    local eclKey=$1

    # TODO: demx2fk3 2014-04-30 implement this

    echo ${eclKey}_${BUILD_NUMBER}
    return
}


