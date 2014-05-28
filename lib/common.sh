#!/bin/bash

source ${LFS_CI_ROOT}/lib/config.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/commands.sh
source ${LFS_CI_ROOT}/lib/exit_handling.sh


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


getBranchName() { 
    getLocationName 
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

mustHaveBranchName() { 
    mustHaveLocationName 
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

    requiredParameters WORKSPACE

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

    # local newLocation=$(getConfig locationMapping)
    local location=$(getLocationName)
    info "switching to new location \"${location}\""
    execute build newlocations ${location}

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
    local masterServer=$(getConfig svnMasterServerHostName)
    local slaveServer=$(getConfig svnSlaveServerUlmHostName)

    info "changing svne1 to ulmscmi"
    perl -pi -e "s/${masterServer}/${slaveServer}/g" \
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

createTempDirectory() {
    mktemp --directory ${LFS_CI_TEMPDIR}/tmp.$$.XXXXXXXXX
}

## @fn      cleanupTempFiles()
#  @brief   reomve all the used temp files
#  @param   <none>
#  @return  <none>
cleanupTempFiles() {
    [[ -d ${LFS_CI_TEMPDIR} ]] && rm -rf ${LFS_CI_TEMPDIR}
}

## @fn      initTempDirectory()
#  @brief   initialize the use for temp directory
#  @param   <none>
#  @return  <none>
initTempDirectory() {
    export LFS_CI_TEMPDIR=$(mktemp -d /tmp/jenkins.${USER}.${JOB_NAME:-unknown}.$$.XXXXXXXXX)
}

initTempDirectory
exit_add cleanupTempFiles


## @fn      requiredParameters( list of variables )
#  @brief   checks, if the given lists of variables names are set and have some valid values
#  @param   list of variable names
#  @return  <none>
#  @throws  raise an error, if there is a variable is not set or has no value
requiredParameters() {
    local parameterNames=$@
    for name in ${parameterNames} ; do
        if [[ ! ${!name} ]] ; then
            error "required parameter ${name} is missing"
            exit 1
        fi
        # echo "${name}=${!name}" >> ${workspace}/../.env
    done

    local workspace=$(getWorkspaceName)


    return
}

## @fn      getNextReleaseLabel()
#  @brief   get the next release label name
#  @param   <none>
#  @return  <none>
getNextReleaseLabel() {
    echo ${LFS_CI_NEXT_LABEL_NAME}
}

## @fn      getNextCiLabelName()
#  @brief   get the next ci label name
#  @param   <none>
#  @return  next ci label name
getNextCiLabelName() {
    echo ${LFS_CI_NEXT_CI_LABEL_NAME}
}

## @fn      mustHaveNextLabelName()
#  @brief   ensure, that there is a release label name
#  @details to get the next release label name, it checks the svn repos
#  @param   <none>
#  @return  <none>
mustHaveNextLabelName() {

    local branch=$(getBranchName)
    mustHaveBranchName

    local regex=${branchToTagRegexMap["${branch}"]}
    mustHaveValue "${regex}" "branch to tag regex map"

    local srcRepos=$(getConfig lfsSourceRepos)

    info "branch ${branch} has release label regex ${regex}"

    local label=$(${LFS_CI_ROOT}/bin/getNewTagName -u ${srcRepos}/os/tags -r "${regex}" )
    mustHaveValue "${label}" "next release label name"

    local taskName=$(getProductNameFromJobName)
    if [[ "${taskName}" == "UBOOT" ]] ; then
        label=$(echo ${label} | sed -e 's/PS_LFS_OS_/LFS/' \
                                    -e 's/PS_LFS_BT_/LBT/' \
                                    -e 's/20//' \
                                    -e 's/_//g')
        info "reajusting label to ${label}"
    fi

    export LFS_CI_NEXT_LABEL_NAME="${label}"

    return
}

## @fn      mustHaveNextCiLabelName()
#  @brief   ensure, that there is a ci label name for this build
#  @param   <none>
#  @return  <none>
mustHaveNextCiLabelName() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    if [[ ! "${LFS_CI_NEXT_CI_LABEL_NAME}" ]] ; then
        local label=$(cat ${workspace}/bld/bld-fsmci-summary/label 2>/dev/null)
        mustHaveValue "${label}" "next ci label name"
    fi

    export LFS_CI_NEXT_CI_LABEL_NAME=${label}
    return
}

## @fn      getJobNameFromUrl()
#  @brief   get the current build directory of the jenkins jobs
#  @param   <none>
#  @return  <none>
getJenkinsJobBuildDirectory() {
    local serverPath=$(getConfig jenkinsMasterServerPath)
    echo ${serverPath}/jobs/${JOB_NAME}/builds/${BUILD_NUMBER}/
}

## @fn      mustHaveValue( $value )
#  @brief   ensure, that the value is a not empty string
#  @param   {value}    just a value
#  @return  <none>
#  @throws  raise an error, if the value is empty
mustHaveValue() {
    local value=$1
    local message="${2:-unkown variable name}"

    if [[ -z "${value}" ]] ; then
        error "excpect a value for ${message}, but didn't got one..."
        exit 1
    fi

    return
}

## @fn      mustHaveWritableFile( fileName )
#  @brief   ensure, that the file is a writable file
#  @param   {fileName}    name of the file
#  @return  <none>
#  @throws  raise an error, if the file is not writable (or not exists)
mustHaveWritableFile() {
    local file=$1
    mustHaveValue "${file}"

    if [[ ! -e ${file} ]] ; then
        error "the file ${file} does not exist"
        exit 1
    fi

    if [[ ! -w ${file} ]] ; then
        error "the file ${file} is not writable"
        exit 1
    fi

    return
}


## @fn      mustExistDirectory( $directoryName )
#  @brief   ensure, that the directory exists 
#  @param   {directoryName}    nae of the directory
#  @return  <none>
#  @throws  raise an error, if the directory is nit exists
mustExistDirectory() {
    local directory=$1

    if [[ ! -d ${directory} ]] ; then
        error "${directory} is not a directory"
        exit 1
    fi
    return
}

mustBeSuccessfull() {
    local rc=$1
    local msg="${2:-unkown message}"

    if [[ ${rc} != 0 ]] ; then
        error "error: ${msg} failed"
        exit 1
    fi
    return
}

removeBrokenSymlinks() {
    local dir=$1
    local tmp=$(createTempFile)

    mustExistDirectory "${dir}"

    execute symlinks -c -d -v -r ${dir} 
    return            
}

getBuildDirectoryOnMaster() {
    local jobName=${1:-$JOB_NAME}
    local buildNumber=${2:-$BUILD_NUMBER}
    local pathName=$(getConfig jenkinsMasterServerPath)

    echo ${pathName}/jobs/${jobName}/builds/${buildNumber}
    return
}

