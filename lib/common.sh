#!/bin/bash

LFS_CI_SOURCE_common='$Id$'

[[ -z ${LFS_CI_SOURCE_config}        ]] && source ${LFS_CI_ROOT}/lib/config.sh
[[ -z ${LFS_CI_SOURCE_logging}       ]] && source ${LFS_CI_ROOT}/lib/logging.sh
[[ -z ${LFS_CI_SOURCE_commands}      ]] && source ${LFS_CI_ROOT}/lib/commands.sh
[[ -z ${LFS_CI_SOURCE_exit_handling} ]] && source ${LFS_CI_ROOT}/lib/exit_handling.sh

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

## @fn      getBranchName()
#  @brief   alias for getLocationName
#  @param   <none>
#  @return  return the branch name
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

## @fn      mustHaveBranchName()
#  @brief   alias for mustHaveLocationName
#  @param   <none>
#  @return  <none>
mustHaveBranchName() { 
    mustHaveLocationName 
}

## @fn      getWorkspaceName()
#  @brief   get the workspace name / directory for the project
#  @param   <none>
#  @return  name / path of the workspace
getWorkspaceName() {
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

    debug "creating a new workspace in \"${workspace}\""

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
    # TODO: demx2fk3 2014-06-16 not implemented
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

    debug "checking out ${project} with revision ${revision:-latest}"
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
    return
}

## @fn      createTempDirectory()
#  @brief   creates a temp directory
#  @param   <none>
#  @return  name of the temp directory
createTempDirectory() {
    mktemp --directory ${LFS_CI_TEMPDIR}/tmp.$$.XXXXXXXXX
    return
}

## @fn      cleanupTempFiles()
#  @brief   reomve all the used temp files
#  @param   <none>
#  @return  <none>
cleanupTempFiles() {
    [[ -d ${LFS_CI_TEMPDIR} ]] && rm -rf ${LFS_CI_TEMPDIR}
    return
}

## @fn      initTempDirectory()
#  @brief   initialize the use for temp directory
#  @param   <none>
#  @return  <none>
initTempDirectory() {
    if [[ -z ${LFS_CI_TEMPDIR} ]] ; then
        export LFS_CI_TEMPDIR=$(mktemp -d /tmp/jenkins.${USER}.${JOB_NAME:-unknown}.$$.XXXXXXXXX)
        exit_add cleanupTempFiles
    fi
    return
}

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
    # echo ${LFS_CI_NEXT_CI_LABEL_NAME}
    getNextReleaseLabel
}

## @fn      mustHavePreviousLabelName()
#  @brief   ensure, that there is a release label name
#  @details to get the next release label name, it checks the svn repos
#  @param   <none>
#  @return  <none>
mustHavePreviousLabelName() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    if [[ ! -e ${workspace}/bld/bld-fsmci-summary/oldLabel ]] ; then
        error "label artifacts file does not exist"
        exit 1
    fi            

    if [[ -z "${LFS_CI_PREV_CI_LABEL_NAME}" ]] ; then
        local label=$(cat ${workspace}/bld/bld-fsmci-summary/oldLabel 2>/dev/null)
        mustHaveValue "${label}" "old ci label name"
    fi

    export LFS_CI_PREV_CI_LABEL_NAME=${label}

    return
}

## @fn      mustHaveNextLabelName()
#  @brief   ensure, that there is a release label name
#  @details to get the next release label name, it checks the svn repos
#  @param   <none>
#  @return  <none>
mustHaveNextLabelName() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    if [[ ! -e ${workspace}/bld/bld-fsmci-summary/label ]] ; then
        error "label artifacts file does not exist"
        exit 1
    fi            

    if [[ -z "${LFS_CI_NEXT_CI_LABEL_NAME}" ]] ; then
        local label=$(cat ${workspace}/bld/bld-fsmci-summary/label 2>/dev/null)
        mustHaveValue "${label}" "next ci label name"
    fi

    export LFS_CI_NEXT_LABEL_NAME=${label}

    return
}
## @fn      mustHaveNextCiLabelName()
#  @brief   ensure, that there is a ci label name for this build
#  @param   <none>
#  @return  <none>
mustHaveNextCiLabelName() {
    mustHaveNextLabelName
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
#  @param   {directoryName}    name of the directory
#  @return  <none>
#  @throws  raise an error, if the directory does not exist
mustExistDirectory() {
    local directory=$1

    if [[ ! -d ${directory} ]] ; then
        error "${directory} is not a directory"
        exit 1
    fi
    return
}

## @fn      mustExistSymlink( $link )
#  @brief   ensure, that the link is a symlink and exists
#  @param   {link}    name of the symlink
#  @return  <none>
#  @throws  raise an error, if the symlink does not exist
mustExistSymlink() {
    local file=$1

    if [[ ! -L ${file} ]] ; then
        error "${file} is not a symlink"
        exit 1
    fi
    return
}

## @fn      mustExistFile( $file )
#  @brief   ensure, that the file exists
#  @param   {file}    name of the file
#  @return  <none>
#  @throws  raise an error, if the file does not exist
mustExistFile() {
    local file=$1

    if [[ ! -f ${file} ]] ; then
        error "${file} is not a file"
        exit 1
    fi
    return
}

## @fn      mustBeSuccessfull( $rc )
#  @brief   ensures, that the given return code is 0, if not it will raise an error
#  @param   {rc}         return code of the command
#  @param   {message}    optional message, which will be displayed
#  @throws  rased an error, if the rc is != 0
mustBeSuccessfull() {
    local rc=$1
    local msg="${2:-unkown message}"

    if [[ ${rc} != 0 ]] ; then
        error "error: ${msg} failed"
        exit 1
    fi
    return
}

## @fn      removeBrokenSymlinks( $dir  )
#  @brief   remove all broken links and fixes "stragne" links in a given directory
#  @param   {dir}    directory to remove broken links
#  @return  <none>
removeBrokenSymlinks() {
    local dir=$1
    local tmp=$(createTempFile)

    mustExistDirectory "${dir}"

    execute symlinks -c -d -v -r ${dir} 
    return            
}

## @fn      getBuildDirectoryOnMaster( $jobName, $buildNumber )
#  @brief   get the build directory in jenkins root on the master server
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    number of the build
#  @return  path of the build 
getBuildDirectoryOnMaster() {
    local jobName=${1:-$JOB_NAME}
    local buildNumber=${2:-$BUILD_NUMBER}
    local pathName=$(getConfig jenkinsMasterServerPath)
    echo ${pathName}/jobs/${jobName}/builds/${buildNumber}
    return
}


## @fn      getWorkspaceDirectoryOfBuild()
#  @brief   get the workspace directory of the build (on the master server only)
#  @param   <none>
#  @return  workspace directory name
getWorkspaceDirectoryOfBuild() {
    local jobName=${1:-$JOB_NAME}

    local pathName=$(getConfig jenkinsMasterServerPath)
    echo ${pathName}/jobs/${jobName}/workspace/workspace/

    return
}

## @fn      copyRevisionStateFileToWorkspace( $jobName, $buildNumber )
#  @brief   copy the revision state file from the jenkins master build directory into the workspace
#  @param   {jobName}       the name of the job
#  @param   {buildNumber}   the number of the build job
#  @return  <none>
copyRevisionStateFileToWorkspace() {
    local jobName=$1
    local buildNumber=$2

    copyFileFromBuildDirectoryToWorkspace ${jobName} ${buildNumber} revisionstate.xml
    mv ${WORKSPACE}/revisionstate.xml ${WORKSPACE}/revisions.txt
    rawDebug ${WORKSPACE}/revisions.txt

    return
}

## @fn      copyChangelogToWorkspace( $jobName, $buildNumber )
#  @brief   copy the changelog from the master into the workspace
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    number of the build
#  @return  <none>
copyChangelogToWorkspace() {
    local jobName=$1
    local buildNumber=$2
    
    copyFileFromBuildDirectoryToWorkspace ${jobName} ${buildNumber} changelog.xml
    rawDebug ${WORKSPACE}/changelog.xml

    return
}

## @fn      copyFileFromBuildDirectoryToWorkspace( $jobName, $buildNumber, $fileName )
#  @brief   copy a specified file from the build directory on the jenkins master to the
#           workspace directory (on the slave)
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    build number of the job
#  @param   {fileName}       name of the file, which should be copied
#  @return  <none>
copyFileFromBuildDirectoryToWorkspace() {
    local jobName=$1
    local buildNumber=$2
    local fileName=$3

    requiredParameters WORKSPACE

    local dir=$(getBuildDirectoryOnMaster ${jobName} ${buildNumber})
    local master=$(getConfig jenkinsMasterServerHostName)

    mustHaveValue "${dir}" "build directory on master"
    debug "copy file ${fileName} from master:${dir} to ${WORKSPACE}"
    execute rsync -avPe ssh ${master}:${dir}/${fileName} ${WORKSPACE}/$(basename ${fileName})

    return        
}

## @fn      copyFileFromWorkspaceToBuildDirectory( $jobName, $buildNumber, $fileName )
#  @brief   copy a specified file from the workspace to the build directory on the
#           jenkins master server
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    build number of the job
#  @param   {fileName}       name of the file, which should be copied
#  @return  <none>
copyFileFromWorkspaceToBuildDirectory() {
    local jobName=$1
    local buildNumber=$2
    local fileName=$3

    requiredParameters WORKSPACE

    local dir=$(getBuildDirectoryOnMaster ${jobName} ${buildNumber})
    local master=$(getConfig jenkinsMasterServerHostName)

    mustHaveValue "${dir}" "build directory on master"
    debug "copy file ${fileName} to master:${dir}"
    execute rsync -avPe ssh ${fileName} ${master}:${dir}/$(basename ${fileName})

    return        
}

## @fn      _getUpstreamProjects( $jobName, $buildNumber, $upstreamsFile )
#  @brief   get the information about a finished upstream job. 
#  @warning internal function
#  @param   {jobName}          name of the job
#  @param   {buildNumber}      build number of the job
#  @param   {upstreamsFile}    file where to store the information
#  @return  <none>
_getUpstreamProjects() {
    local jobName=$1
    local buildNumber=$2
    local upstreamsFile=$3

    requiredParameters LFS_CI_ROOT 

    local serverPath=$(getConfig jenkinsMasterServerPath)
    mustHaveValue "${serverPath}" "server path"
    mustExistDirectory ${serverPath}

    # find the related jobs of the build
    runOnMaster ${LFS_CI_ROOT}/bin/getUpStreamProject \
                    -j ${jobName}                     \
                    -b ${buildNumber}                 \
                    -h ${serverPath} > ${upstreamsFile}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    return
}

## @fn      _getJobInformationFromUpstreamProject( $jobName, $buildNumber, $jobNamePart, $fieldNumber  )
#  @brief   get the information about a job from a finished upstream job
#  @warning internal function
#  @param   {jobName}       name of the job
#  @param   {buildNumber}    build number of the job
#  @param   {jobNamePart}    part of the job name, which we are looking for
#  @param   {fieldNumber}    field number (interal)
#  @return  requested information about the job
_getJobInformationFromUpstreamProject() {
    local jobName=$1
    local buildNumber=$2
    local jobNamePart=$3
    local fieldNumber=$4

    local upstreamsFile=$(createTempFile)

    _getUpstreamProjects ${jobName} ${buildNumber} ${upstreamsFile}
    local resultValue=$(grep ${jobNamePart} ${upstreamsFile} | cut -d: -f${fieldNumber})
    mustHaveValue ${resultValue} "requested info / ${jobNamePart} / ${fieldNumber}"

    echo ${resultValue}
    return
}

## @fn      getTestBuildNumberFromUpstreamProject( $jobName, $buildNumber )
#  @brief   get the test job build number from specified, finished upstream project
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    build number of the job
#  @return  test job build number
getTestBuildNumberFromUpstreamProject() {
    local jobName=$1
    local buildNumber=$2
    _getJobInformationFromUpstreamProject ${jobName} ${buildNumber} Test 2
    return
}

## @fn      getTestJobNameFromUpstreamProject( $jobName, $buildNumber )
#  @brief   get the test job name from specified, finished upstream project
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    build number of the job
#  @return  test job name 
getTestJobNameFromUpstreamProject() {
    local jobName=$1
    local buildNumber=$2
    _getJobInformationFromUpstreamProject ${jobName} ${buildNumber} Test 1
    return
}

## @fn      getBuildBuildNumberFromUpstreamProject( $jobName, $buildNumber )
#  @brief   get the build build number from specified, finished upstream project
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    build number of the job
#  @return  build job build number
getBuildBuildNumberFromUpstreamProject() {
    local jobName=$1
    local buildNumber=$2
    _getJobInformationFromUpstreamProject ${jobName} ${buildNumber} Build 2
    return
}

## @fn      getBuildJobNameFromUpstreamProject( $jobName, $buildNumber )
#  @brief   get the build name from specified, finished upstream project
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    build number of the job
#  @return  build job name
getBuildJobNameFromUpstreamProject() {
    local jobName=$1
    local buildNumber=$2
    _getJobInformationFromUpstreamProject ${jobName} ${buildNumber} Build 1
    return
}

## @fn      getPackageBuildNumberFromUpstreamProject( $jobName, $buildNumber )
#  @brief   get the package build number from specified, finished upstream project
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    build number of the job
#  @return  package build number
getPackageBuildNumberFromUpstreamProject() {
    local jobName=$1
    local buildNumber=$2
    _getJobInformationFromUpstreamProject ${jobName} ${buildNumber} Package 2
    return
}

## @fn      getPackageJobNameFromUpstreamProject( $jobName, $buildNumber )
#  @brief   get the package build name from specified, finished upstream project
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    build number of the job
#  @return  package job name
getPackageJobNameFromUpstreamProject() {
    local jobName=$1
    local buildNumber=$2
    _getJobInformationFromUpstreamProject ${jobName} ${buildNumber} Package 1
    return
}

