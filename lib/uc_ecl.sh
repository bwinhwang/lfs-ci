#!/bin/bash

## @fn      ci_job_ecl()
#  @brief   update the ECL file 
#  @details «full description»
#  @todo    add more doc
#  @param   <none>
#  @return  <none>
ci_job_ecl() {
    requiredParameters JOB_NAME BUILD_NUMBER 

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    local eclUrl=$(getConfig LFS_CI_uc_update_ecl_url)
    mustHaveValue ${eclUrl}

    local eclKeysToUpdate=$(getConfig LFS_CI_uc_update_ecl_key_names)
    mustHaveValue "${eclKeysToUpdate}"

    info "checkout ECL from ${eclUrl}"
    svnCheckout ${eclUrl} ${workspace}/ecl_checkout
    mustHaveWritableFile ${workspace}/ecl_checkout/ECL

    for eclKey in ${eclKeysToUpdate} ; do

        local oldEclValue=$(grep "^${eclKey}=" ${workspace}/ecl_checkout/ECL | cut -d= -f2)
        local eclValue=$(getEclValue "${eclKey}" "${oldEclValue}")
        mustHaveValue "${eclKey}"
        mustHaveValue "${eclValue}"

        info "update ecl key ${eclKey} with value ${eclValue} (old: ${oldEclValue})"
        execute perl -pi -e "s:^${eclKey}=.*:${eclValue}=${value}:" ${workspace}/ecl_checkout/ECL

    done

    svnDiff ${workspace}/ecl_checkout/ECL

    # TODO: demx2fk3 2014-05-05 not fully implemented
    info "TODO: commit new ECL"

    return
}

## @fn      getEclValue(  )
#  @brief   get the Value for the ECL for a specified key
#  @todo    implement this
#  @param   {eclKey}    name of the key from ECL
#  @return  value for the ecl key
getEclValue() {
    local eclKey=$1
    local oldValue=$2

    # TODO: demx2fk3 2014-04-30 implement this
    echo ${eclKey}_${BUILD_NUMBER}
    return
}


