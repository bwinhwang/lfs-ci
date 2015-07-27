#!/bin/bash
## @file  common.sh
#  @brief common functions

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
    local targetName=$(getTargetBoardName) 
    mustHaveValue "${targetName}" "correct target board name from JOB_NAME ${JOB_NAME}"
    return
}

## @fn      getBranchName()
#  @brief   alias for getLocationName
#  @param   <none>
#  @return  return the branch name
getBranchName() { 
    getLocationName $@
}

## @fn      mustHaveLocationName()
#  @brief   ensure, that there is a location name (aka branch)
#  @param   <none>
#  @return  <none>
#  @throws  raises an error, if there is no location name
mustHaveLocationName() {
    local location=$(getLocationName) 
    mustHaveValue "${location}" "correct location name from JOB_NAME ${JOB_NAME}"
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
    local workspace=$(getWorkspaceName) 
    mustHaveValue "${workspace}" "workspace location on disk"
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
        fatal "workspace ${workspace} is not writable"
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

## @fn      switchToNewLocation()
#  @brief   swtich to the new location / branch (aka build newlocation <branch>)
#  @param   {locationName}   the new location name aka branch name
#  @return  <none>
switchToNewLocation() {
    local location=${1:-$(getLocationName)}

    # TODO: demx2fk3 2014-03-28 fixme
    # trace "check, if user can use this location"
    # if id -ng ${USER} | grep pronb ; then
    #     fatal "${USER} has wrong group id. correct is pronb"
    # fi

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
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    debug "creating a new workspace in \"${workspace}\""

    execute cd "${workspace}"
    execute build setup
    return
}


## @fn      createBasicWorkspace()
#  @brief   create a new workspace with the given parameters
#  @warning This can be only used, if you know, what you want. 
#           This is not in use for creation of a build workspace.
#           This can be used for create a workspace for running tests.
#  @param   {opt}    option: -l <location name>
#  @param   {components}    list of component names
#  @return  <none>
createBasicWorkspace() {
    local opt=$1
    local location=

    # TODO: demx2fk3 2014-12-16 use getopt here
    if [[ ${opt} = "-l" ]] ; then
        location=$2
        shift 2
    fi

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    local components=$@

    setupNewWorkspace
    switchToNewLocation ${location}
    switchSvnServerInLocations

    for component in ${components} ; do
        execute build adddir ${component}
    done
   
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

    if ! grep -q "ulm" <<< ${NODE_LABELS} ; then
        return
    fi

    local workspace=$(getWorkspaceName) 
    local masterServer=$(getConfig svnMasterServerHostName)
    local slaveServer=$(getConfig svnSlaveServerUlmHostName)
    local location=$(getLocationName)

    info "changing svne1 to ulmscmi"
    perl -pi -e "s/${masterServer}/${slaveServer}/g" \
        ${workspace}/locations/locations-*/Dependencies

    execute svn status ${workspace}/locations/locations-*/Dependencies
    execute svn diff   ${workspace}/locations/locations-*/Dependencies

    return
}

## @fn      checkoutSubprojectDirectories()
#  @brief   checkout a subsystem of LFS using build command with a revision
#  @param   {subsystem}    name of the src-directory
#  @param   {revision}     revision number from svn, which should be used
#  @param   <none>
#  @return  <none>
checkoutSubprojectDirectories() {
    local workspace=$(getWorkspaceName) 
    local project=$1
    local revision=$2
    if [[ ${revision} && ${revision} =~ ^[0-9]*$ ]] ; then
        optRev="--revision=${revision}"
    elif [[ ${revision} ]] ; then
        # not a numeric revision, so it should be a tag
        optRev="${revision}"
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

## @fn      requiredParameters()
#  @brief   checks, if the given lists of variables names are set and have some valid values
#  @param   list of variable names
#  @return  <none>
#  @throws  raise an error, if there is a variable is not set or has no value
requiredParameters() {
    local parameterNames=$@
    if [[ -z ${LFS_CI_INTERNAL_RERUN_ENVIRONMENT_FILE} ]] ; then
        export LFS_CI_INTERNAL_RERUN_ENVIRONMENT_FILE=$(createTempFile)
    fi
    for name in ${parameterNames} ; do
        if [[ ! ${!name} ]] ; then
            fatal "required parameter ${name} is missing"
        fi
        echo "export ${name}=\"${!name}\"" >> ${LFS_CI_INTERNAL_RERUN_ENVIRONMENT_FILE}
    done

    return
}

## @fn      logRerunCommand()
#  @brief   record the command incl. environment variables, which are needed to rerun the jenkins job
#  @param   <none>
#  @return  <none>
logRerunCommand() {
    rerun=$(createTempFile)
    echo "#!/bin/bash" > ${rerun}
    execute -n sort -u ${LFS_CI_INTERNAL_RERUN_ENVIRONMENT_FILE} >> ${rerun}
    echo $0 ${JOB_NAME} >> ${rerun}
    rawDebug ${rerun}
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
        fatal "label artifacts file does not exist"
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
        fatal "label artifacts file does not exist"
    fi            

    if [[ -z "${LFS_CI_NEXT_CI_LABEL_NAME}" ]] ; then
        local label=$(cat ${workspace}/bld/bld-fsmci-summary/label 2>/dev/null)
        debug "labelName is ${label}"
        mustHaveValue "${label}" "next ci label name"
        export LFS_CI_NEXT_LABEL_NAME=${label}
    fi

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

## @fn      getJenkinsJobBuildDirectory()
#  @brief   get the build directory on jenkins master server
#  @param   <none>
#  @return  location of the build directory on jenkins master server
getJenkinsJobBuildDirectory() {
    requiredParameters JOB_NAME BUILD_NUMBER

    local serverPath=$(getConfig jenkinsMasterServerPath)
    mustHaveValue "${serverPath}" "jenkins path on master"

    echo ${serverPath}/jobs/${JOB_NAME}/builds/${BUILD_NUMBER}/
    return
}

## @fn      mustHaveValue()
#  @brief   ensure, that the value is a not empty string
#  @param   {value}    just a value. Always use double quotes eg "$var1"
#  @return  <none>
#  @throws  raise an error, if the value is empty
mustHaveValue() {
    local value=$1
    local message="${2:-unkown variable name}"

    if [[ -z "${value}" ]] ; then
        fatal "excpect a value for ${message}, but didn't got one..."
    fi

    return
}

## @fn      mustHaveWritableFile()
#  @brief   ensure, that the file is a writable file
#  @param   {fileName}    name of the file
#  @return  <none>
#  @throws  raise an error, if the file is not writable (or not exists)
mustHaveWritableFile() {
    local file=$1
    mustHaveValue "${file}"

    if [[ ! -e ${file} ]] ; then
        fatal "the file ${file} does not exist"
    fi

    if [[ ! -w ${file} ]] ; then
        fatal "the file ${file} is not writable"
    fi

    return
}

## @fn      mustExistDirectory()
#  @brief   ensure, that the directory exists 
#  @param   {directoryName}    name of the directory
#  @return  <none>
#  @throws  raise an error, if the directory does not exist
mustExistDirectory() {
    local directory=$1

    if [[ ! -d ${directory} ]] ; then
        fatal "${directory} is not a directory"
    fi
    return
}

## @fn      mustExistSymlink()
#  @brief   ensure, that the link is a symlink and exists
#  @param   {link}    name of the symlink
#  @return  <none>
#  @throws  raise an error, if the symlink does not exist
mustExistSymlink() {
    local file=$1

    if [[ ! -L ${file} ]] ; then
        fatal "${file} is not a symlink"
    fi
    return
}

## @fn      mustExistFile()
#  @brief   ensure, that the file exists
#  @param   {file}    name of the file
#  @return  <none>
#  @throws  raise an error, if the file does not exist
mustExistFile() {
    local file=$1

    if [[ ! -f ${file} ]] ; then
        fatal "${file} is not a file"
    fi
    return
}

## @fn      mustBeSuccessfull()
#  @brief   ensures, that the given return code is 0, if not it will raise an error
#  @param   {rc}         return code of the command
#  @param   {message}    optional message, which will be displayed
#  @throws  rased an error, if the rc is != 0
mustBeSuccessfull() {
    local rc=$1
    local msg="${2:-unkown message}"

    if [[ ${rc} != 0 ]] ; then
        fatal "error: ${msg} failed"
    fi
    return
}

## @fn      removeBrokenSymlinks()
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

## @fn      getBuildDirectoryOnMaster()
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

## @fn      copyRevisionStateFileToWorkspace()
#  @brief   copy the revision state file from the jenkins master build directory into the workspace
#  @param   {jobName}       the name of the job
#  @param   {buildNumber}   the number of the build job
#  @return  <none>
copyRevisionStateFileToWorkspace() {
    local jobName=$1
    local buildNumber=$2

    [[ -z ${jobName} ]] && return

    copyFileFromBuildDirectoryToWorkspace ${jobName} ${buildNumber} revisionstate.xml
    mv ${WORKSPACE}/revisionstate.xml ${WORKSPACE}/revisions.txt
    rawDebug ${WORKSPACE}/revisions.txt

    return
}

## @fn      copyChangelogToWorkspace()
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

## @fn      copyFileFromBuildDirectoryToWorkspace()
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
    execute -r 10 rsync -avPe ssh ${master}:${dir}/${fileName} ${WORKSPACE}/$(basename ${fileName})

    return        
}

## @fn      copyFileFromWorkspaceToBuildDirectory()
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
    execute -r 10 rsync -avPe ssh ${fileName} ${master}:${dir}/$(basename ${fileName})

    return        
}

## @fn      _getUpstreamProjects()
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

    # find the related jobs of the build
    # TODO: demx2fk3 2015-01-23 KNIFE FIXME
    local server=$(getConfig jenkinsMasterServerHostName)
    mustHaveValue "${server}" "server name"
    execute -n -r 10 ssh ${server}                    \
            ${LFS_CI_ROOT}/bin/getUpStreamProject     \
                    -j ${jobName}                     \
                    -b ${buildNumber}                 \
                    -h ${serverPath} > ${upstreamsFile}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    return
}

## @fn      _getDownstreamProjects()
#  @brief   get the information about a finished downstream job. 
#  @warning internal function
#  @param   {jobName}          name of the job
#  @param   {buildNumber}      build number of the job
#  @param   {upstreamsFile}    file where to store the information
#  @return  <none>
_getDownstreamProjects() {
    local jobName=$1
    local buildNumber=$2
    local downstreamFile=$3

    requiredParameters LFS_CI_ROOT 

    local serverPath=$(getConfig jenkinsMasterServerPath)
    mustHaveValue "${serverPath}" "server path"

    # TODO: demx2fk3 2015-01-23 KNIFE FIXME
    local server=$(getConfig jenkinsMasterServerHostName)
    mustHaveValue "${server}" "server name"
    execute -n -r 10 ssh ${server}                      \
            ${LFS_CI_ROOT}/bin/getDownStreamProjects    \
                    -j ${jobName}                       \
                    -b ${buildNumber}                   \
                    -h ${serverPath}  > ${downstreamFile}
    rawDebug ${downstreamFile}

    return
}

## @fn      getDownStreamProjectsData()
#  @brief   get the down stream data of a project
#  @details you have the project name and a build number and you want
#           all jobs, which where triggered by this build job.
#  @param   {jobName}        name of a project
#  @param   {buildNumber}    number of a build job
#  @return  all triggered subjobs
getDownStreamProjectsData() {
    local jobName=$1
    local buildNumber=$2

    local file=$(createTempFile)

    _getDownstreamProjects ${jobName} ${buildNumber} ${file}

    cat ${file}
    return
}

## @fn      _getJobInformationFromUpstreamProject()
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
    local resultValue=$(grep ${jobNamePart} ${upstreamsFile} | cut -d: -f${fieldNumber} | sort -n | tail -n 1 )
    mustHaveValue ${resultValue} "requested info / ${jobNamePart} / ${fieldNumber}"

    echo ${resultValue}
    return
}

## @fn      getTestBuildNumberFromUpstreamProject()
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

## @fn      getTestJobNameFromUpstreamProject()
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

## @fn      getBuildBuildNumberFromUpstreamProject()
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

## @fn      getBuildJobNameFromUpstreamProject()
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

## @fn      getPackageBuildNumberFromUpstreamProject()
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

## @fn      getPackageJobNameFromUpstreamProject()
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

## @fn      mustHaveAccessableServer()
#  @brief   ensure, that a server is accessable
#  @param   {serverName}    name of the server, which should be accessable
#  @return  <none>
mustHaveAccessableServer() {
    # TODO: demx2fk3 2014-12-16 not implemented yet
    return
}

## @fn      getBranchPart()
#  @brief   provides the parts of a branch name
#  @param   <branch> the name of a branch eg FB1408
#  @param   <what> the part to get. Can be YY | YYYY | MM | NR | TYPE
#           NR is only valid for MD branches.
#  @return  <none>
getBranchPart() {
    local branch=$1
    local what=$2
    [[ $(echo $branch | cut -c1-4) == "LRC_" ]] && branch=$(echo $branch | cut -d'_' -f2)
    local branchType=$(echo ${branch} | cut -c1,2)

    if [[ "${branchType}" == "FB" ]]; then
        local yy=$(echo ${branch}  | cut -c3,4)
        local mm=$(echo ${branch}  | cut -c5,6)
        local yyyy=$((2000+yy))
    elif [[ "${branchType}" == "MD" ]]; then
        local yy=$(echo ${branch}  | cut -c4,5)
        local nr=$(echo ${branch}  | cut -c3)
        local mm=$(echo ${branch}  | cut -c6,7)
        local yyyy=$((2000+yy))
        branchType=$(echo $branch | cut -c1-3)
    else
        error "Only FB and MD branches are supported."
        return 1
    fi

    [[ ${what} == YY ]] && echo ${yy}
    [[ ${what} == YYYY ]] && echo ${yyyy}
    [[ ${what} == MM ]] && echo ${mm}
    [[ ${what} == TYPE ]] && echo ${branchType}
    [[ ${what} == NR ]] && echo ${nr}
}

## @fn      mustHaveFreeDiskSpace()
#  @brief   ensure, that there is enough free diskspace on given filesystem
#  @param   {filesystem}    path of the filesystem (e.g. /var/fpwork)
#  @param   {requiredSpace}    required free diskspace on the filesystem in kilobytes
#  @return  <none>
mustHaveFreeDiskSpace() {
    local filesystem=$1
    mustExistDirectory ${filesystem}

    local requiredSpace=$2
    mustHaveValue "${requiredSpace}" "required disk space in kb"

    local free=$(execute -n df -k ${filesystem} | tail -1 | awk '{print $4}')
    mustHaveValue "${free}" "free diskspace of ${filesystem}"

    if [[ ${free} -gt ${requiredSpace} ]] ; then
        return
    fi

    fatal "not enough disk space on ${filesystem}. Free ${free}, required ${requiredSpace}"
}

## @fn      sanityCheck()
#  @brief   checks some very important stuff everytime, before starting some usecase
#  @details the sanity check is checking some common issues
#           * is there a not versioned / checkedin file in the ${LFS_CI_ROOT}
#           * is the job name a known job name (from the naming schema)
#           * is the branch name of the current job the same branch of the upstream project
#  @param   <none>
#  @return  <none>
#  @throws  raise an error, if something is wrong
sanityCheck() {
    requiredParameters LFS_CI_ROOT JOB_NAME 

    local LFS_CI_git_version=$(cd ${LFS_CI_ROOT} ; git describe)
    debug "used lfs ci git version ${LFS_CI_git_version}"
    local runSanityCheck=$(getConfig LFS_CI_GLOBAL_should_run_sanity_checks)

    if [[ ${runSanityCheck} -eq 1 ]]; then
        # we do not want to have modifications in ${LFS_CI_ROOT}
        local waitForGit=$(getConfig LFS_CI_waitForGit)
        local LFS_CI_git_local_modifications=$(cd ${LFS_CI_ROOT} ; git status --short | wc -l)
        if [[ ${LFS_CI_git_local_modifications} -gt 0 ]] ; then
            info "there are local modifications which are not commited - waiting for ${waitForGit} sec."
            sleep ${waitForGit}
            LFS_CI_git_local_modifications=$(cd ${LFS_CI_ROOT} ; git status --short | wc -l)
            if [[ ${LFS_CI_git_local_modifications} -gt 0 ]] ; then
                fatal "the are local modifications in ${LFS_CI_ROOT}, which are not commited. "\
                  "CI is rejecting such kind of working mode and refused to work until the modifications are commited. "\
                  "Increase config. parameter LFS_CI_waitForGit."
            fi
        fi
    fi

    # check job name convetions
    if [[ ${JOB_NAME} =~ Admin_-_.* ]] ; then
        debug "admin job, naming is ok"
    elif [[ ${JOB_NAME} =~ Test-.* ]] ; then
        debug "test job, naming is ok"
    elif [[ ${JOB_NAME} =~ LFS_.*   || \
            ${JOB_NAME} =~ UBOOT_.* || \
            ${JOB_NAME} =~ LTK_.*   || \
            ${JOB_NAME} =~ PKGPOOL_.* ]] ; then
        debug "normal build / test / release job, naming is ok"

        # checking for same branch of upstream and current job. 
        # this should not be different
        # if [[ ${UPSTREAM_PROJECT} ]] ; then
        #     local branchName=$(getBranchName)
        #     local upstreamBranchName=$(getBranchName ${UPSTREAM_PROJECT})
        #     if [[ ${branchName} != ${upstreamBranchName} ]] ; then
        #         fatal "wrong configuration: upstream project ${UPSTREAM_PROJECT} is in a different branch as current job ${JOB_NAME}. "\
        #               "Check the configuration of the jenkins projects."
        #     fi
        # fi
    else
        fatal "unknown job type."
    fi

    return
}


## @fn      createFingerprintFile()
#  @brief   create a file which can be used for fingerprinting
#  @param   <none>
#  @return  <none>
createFingerprintFile() {
    requiredParameters JOB_NAME BUILD_NUMBER WORKSPACE 

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    # we are creating a finger print file with several informations to have a unique 
    # build identifier. we are also storing the file in the build directory
    copyRevisionStateFileToWorkspace ${JOB_NAME} ${BUILD_NUMBER} 
    mv ${WORKSPACE}/revisions.txt ${workspace}/bld/bld-fsmci-summary/revisions.txt

    echo "# build label ${label}"                             > ${workspace}/fingerprint.txt
    echo "# triggered build job ${JOB_NAME}#${BUILD_NUMBER}" >> ${workspace}/fingerprint.txt
    echo "# trigger cause: ${BUILD_CAUSE_SCMTRIGGER}"        >> ${workspace}/fingerprint.txt
    echo "# build triggered at $(date)"                      >> ${workspace}/fingerprint.txt
    cat ${workspace}/bld/bld-fsmci-summary/revisions.txt     >> ${workspace}/fingerprint.txt

    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${workspace}/fingerprint.txt
    execute cp ${workspace}/fingerprint.txt ${workspace}/bld/bld-fsmci-summary/

    return
}
