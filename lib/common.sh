#!/bin/bash

# the following methods are parsing the jenkins job name and return the
# required / requested information. At the moment, the script will be called
# every time. This is normally not so fast as it should be.
# TODO: demx2fk3 2014-03-27 it should be done in this way:
#  * check, if there is a "property" file which includes the information
#  * if the files does not exist, create a new file with all information
#  * source the new created file
#  * use the sourced information
# this is caching the information

getTaskNameFromJobName() {
    getFromString.pl "${JENKINS_JOB_NAME}" taskName
    return
}

getSubTaskNameFromJobName() {
    getFromString.pl "${JENKINS_JOB_NAME}" subTaskName
    return
}

getTargetBoardName() {
    getFromString.pl "${JENKINS_JOB_NAME}" platform
    return
}

mustHaveTargetBoardName() {

    local location=$(getTargetBoardName) 
    if [[ ! ${location} ]] ; then
        error "can not get the correction target board name from JENKINS_JOB_NAME \"${JENKINS_JOB_NAME}\""
        exit 1
    fi

}

getLocationName() {
    local location=$(getFromString.pl "${JENKINS_JOB_NAME}" location)

    # 2014-02-17 demx2fk3 TODO do this in a better wa
    case ${location} in
        trunk)
            trace "TODO: mapping location name from trunk to pronb-developer"
            echo pronb-developer
        ;;
        *)
            echo ${location}
        ;;
    esac

    return
}

mustHaveLocationName() {

    local location=$(getLocationName) 
    if [[ ! ${location} ]] ; then
        error "can not get the correction location name from JENKINS_JOB_NAME \"${JENKINS_JOB_NAME}\""
        exit 1
    fi

}

getWorkspaceName() {
    local location=$(getLocationName)
    mustHaveLocationName

    echo "${WORKSPACE}/workspace"
}

mustHaveWorkspaceName() {

    local workspace=$(getWorkspaceName) 
    if [[ ! "${workspace}" ]] ; then
        error "can not get the correction workspace name from JENKINS_JOB_NAME \"${JENKINS_JOB_NAME}\""
        exit 1
    fi
}

mustHaveWritableWorkspace() {
    local workspace=$(getWorkspaceName) 
    mustHaveWorkspaceName

    if [[ ! -w "${workspace}" ]] ; then
        error "workspace ${workspace} is not writable"
        exit 1
    fi
}

mustHaveCleanWorkspace() {

    local workspace=$(getWorkspaceName) 
    mustHaveWorkspaceName

    if [[ -d "${workspace}" ]] ; then
        trace "creating new workspace directory \"${workspace}\""
        removeWorkspace "${workspace}"
    fi

    trace "creating new workspace directory \"${workspace}\""
    execute mkdir -p "${workspace}"
}

removeWorkspace() {
    local workspace=$1

    execute chmod -R u+w "${workspace}"
    execute rm -rf "${workspace}"
}

switchToNewLocation() {
    local location=$1

    trace "check, if user can use this location"
    # 2014-02-17 demx2fk3 fixme
    # if id -ng ${USER} | grep pronb ; then
    #     error "${USER} has wrong group id. correct is pronb"
    #     exit 1
    # fi

    newLocation=$(getConfig locationMapping)

    trace "switching to new location \"${newLocation}\""
    execute build newlocations ${newLocation}
}

# side effect: change directory
setupNewWorkspace() {
    local workspace=$(getWorkspaceName) 
    execute cd "${workspace}"
    execute build setup                                                                                                
}
## @fn      mustHaveValidWorkspace()
#  @brief   ensure, that the workspace is valid
#  @todo    not implemented yet
#  @param   <none>
#  @return  <none>
#  @throws  an error, if the workspace is not valid
mustHaveValidWorkspace() {
    return
}

## @fn      switchSvnServerInLocations()
#  @brief   change the svn server in the location/*/Dependencies files
#  @details the connection from svne1 to ulm is very slow. So we want to use
#           the ulm slave server for checkouts. This is much faster
#           changes are documented in the logfile
#  @param   <none>
#  @return  <none>
switchSvnServerInLocations() {
    local workspace=$(getWorkspaceName) 

    info "changing svne1 to ulmscmi"
    perl -pi -e "s/${svnMasterServerHostName}/${svnSlaveServerUlmHostName}/g" \
        locations/*/Dependencies

    execute svn status locations/*/Dependencies
    execute svn diff   locations/*/Dependencies

    return
}
## @fn      checkoutSubprojectDirectories( subsystem, revision )
#  @brief   checkout a subsystem of LFS using build command with a revision
#  @param   {subsystem}    name of the src-directory
#  @param   {revision}     revision number from svn, which should be used
#  @param   <none>
#  @return  <none>
checkoutSubprojectDirectories() {
    local workspace=$(getWorkspaceName) 
    local project=$1
    local revision=$2
    if [[ ${revision} ]] ; then
        optRev="--revision=${revision}"
    fi
    execute build adddir "${project}" ${optRev}

    return
}

## @fn      createTempFile()
#  @brief   create a temp file
#  @details it takes care, that the temp file will be removed in any case, if the programm exits
#  @param   <none>
#  @return  name of the new created temp file
createTempFile() {
    local tempfile=$(mktemp)
    GLOBAL_tempfiles=("${tempfile}" "${GLOBAL_tempfiles[@]}")
    echo ${tempfile}
}

## @fn      cleanupTempFiles()
#  @brief   reomve all the used temp files
#  @param   <none>
#  @return  <none>
cleanupTempFiles() {
    for file in ${GLOBAL_tempfiles[@]}
    do
        rm -rf ${file}            
    done
}

declare -a GLOBAL_tempfiles 
exit_add cleanupTempFiles
