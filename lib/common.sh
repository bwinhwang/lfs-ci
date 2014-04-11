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

# the syntax of the jenkins job name is:
#
# LFS _ ( CI | PROD ) _-_ <branch> _-_ <task> _-_ <build> _-_ <boardName>
#

## @fn      getTaskNameFromJobName()
#  @brief   get the task name from the jenkins job name
#  @param   <none>
#  @return  task name
getTaskNameFromJobName() {
    ${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" taskName
    return
}

## @fn      getSubTaskNameFromJobName()
#  @brief   get the sub task name from the jenkins job name
#  @param   <none>
#  @return  sub task name
getSubTaskNameFromJobName() {
    ${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" subTaskName
    return
}

## @fn      getTargetBoardName()
#  @brief   get the target board name from the jenkins job name
#  @param   <none>
#  @return  target board name
getTargetBoardName() {
    ${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" platform
    return
}

## @fn      mustHaveTargetBoardName()
#  @brief   ensure, that there is a target board name
#  @param   <none>
#  @return  <none>
#  @throws  raise an error, if there is no target board name
mustHaveTargetBoardName() {

    local location=$(getTargetBoardName) 
    if [[ ! ${location} ]] ; then
        error "can not get the correction target board name from JOB_NAME \"${JOB_NAME}\""
        exit 1
    fi

    return
}

## @fn      getLocationName()
#  @brief   get the location name (aka branch) from the jenkins job name
#  @param   <none>
#  @return  location name
getLocationName() {
    local location=$(${LFS_CI_ROOT}/bin/getFromString.pl "${JOB_NAME}" location)

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

## @fn      mustHaveLocationName()
#  @brief   ensure, that there is a location name (aka branch)
#  @param   <none>
#  @return  <none>
#  @throws  raises an error, if there is no location name
mustHaveLocationName() {

    local location=$(getLocationName) 
    if [[ ! ${location} ]] ; then
        error "can not get the correction location name from JOB_NAME \"${JOB_NAME}\""
        exit 1
    fi

    return
}

## @fn      getWorkspaceName()
#  @brief   get the workspace name / directory for the project
#  @param   <none>
#  @return  name / path of the workspace
getWorkspaceName() {
    local location=$(getLocationName)
    mustHaveLocationName

    echo "${WORKSPACE}/workspace"

    return
}

## @fn      mustHaveWorkspaceName()
#  @brief   ensure, that there is a workspace name
#  @param   <none>
#  @return  <none>
#  @throws  raise an error, if there is no workspace name avaibale
mustHaveWorkspaceName() {

    local workspace=$(getWorkspaceName) 
    if [[ ! "${workspace}" ]] ; then
        error "can not get the correction workspace name from JOB_NAME \"${JOB_NAME}\""
        exit 1
    fi

    return
}

## @fn      mustHaveWritableWorkspace()
#  @brief   ensure, that the workspace is writable
#  @param   <none>
#  @return  <none>
#  @throws  raise an error, if the workspace is not writable
mustHaveWritableWorkspace() {
    local workspace=$(getWorkspaceName) 
    mustHaveWorkspaceName

    if [[ ! -w "${workspace}" ]] ; then
        error "workspace ${workspace} is not writable"
        exit 1
    fi

    return
}

## @fn      mustHaveCleanWorkspace()
#  @brief   ensure, that the workspace is clean.
#  @details if the workspace exists, the workspace directory will be removed and recreated
#  @param   <none>
#  @return  <none>
mustHaveCleanWorkspace() {

    local workspace=$(getWorkspaceName) 
    mustHaveWorkspaceName

    if [[ -d "${workspace}" ]] ; then
        trace "creating new workspace directory \"${workspace}\""
        removeWorkspace "${workspace}"
    fi

    trace "creating new workspace directory \"${workspace}\""
    execute mkdir -p "${workspace}"

    return
}

## @fn      removeWorkspace()
#  @brief   remove the workspace directory
#  @todo    for big workspaces, move the directory into a trash folder and
#           remove the workspace later
#  @param   <none>
#  @return  <none>
removeWorkspace() {
    local workspace=$1

    execute chmod -R u+w "${workspace}"
    execute rm -rf "${workspace}"

    return
}

## @fn      switchToNewLocation( locationName )
#  @brief   swtich to the new location / branch (aka build newlocation <branch>)
#  @param   {locationName}   the new location name aka branch name
#  @return  <none>
switchToNewLocation() {
    local location=$1

    trace "check, if user can use this location"
    # TODO: demx2fk3 2014-03-28 fixme
    # if id -ng ${USER} | grep pronb ; then
    #     error "${USER} has wrong group id. correct is pronb"
    #     exit 1
    # fi

    newLocation=$(getConfig locationMapping)

    trace "switching to new location \"${newLocation}\""
    execute build newlocations ${newLocation}

    return
}

## @fn      setupNewWorkspace()
#  @brief   setup a new workspace (aka build setup)
#  @warning side effect: this change the current directory into the workspace!!
#  @param   <none>
#  @return  <none>
setupNewWorkspace() {
    local workspace=$(getWorkspaceName) 
    execute cd "${workspace}"
    execute build setup                                                                                                

    return
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
    mktemp ${LFS_CI_TEMPDIR}/tmp.$$.XXXXXXXXX
}

## @fn      cleanupTempFiles()
#  @brief   reomve all the used temp files
#  @param   <none>
#  @return  <none>
cleanupTempFiles() {
    [[ -d ${LFS_CI_TEMPDIR} ]] && rm -rf ${LFS_CI_TEMPDIR}
}

initTempDirectory() {
    export LFS_CI_TEMPDIR=$(mktemp -d /tmp/jenkins.${USER}.${JOB_NAME:-unknown}.$$.XXXXXXXXX)
}

initTempDirectory
exit_add cleanupTempFiles


requiredParameters() {
    local parameterNames=$@
    for name in ${parameterNames} ; do
        if [[ ! ${!name} ]] ; then
            error "required parameter ${name} is missing"
            exit 1
        fi
    done
}

