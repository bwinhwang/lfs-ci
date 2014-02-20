#!/bin/bash
getTargetBoardName() {

    local regex='LFS_production_([[:alpha:]]*)_-_([[:alpha:]]*)_([[:alpha:]]*).*'

    trace "JENKINS_JOB_NAME = ${JENKINS_JOB_NAME}"

    if [[ ${JENKINS_JOB_NAME} =~ ${regex} ]] ; then
        case ${BASH_REMATCH[3]} in
            *) echo ${BASH_REMATCH[3]} ;;
        esac
    fi
    
}

mustHaveTargetBoardName() {

    local location=$(getTargetBoardName) 
    if [[ ! ${location} ]] ; then
        error "can not get the correction target board name from JENKINS_JOB_NAME \"${JENKINS_JOB_NAME}\""
        exit 1
    fi

}

getLocationName() {

    local regex='LFS_production_([[:alpha:]]*)_-_([[:alpha:]]*)_([[:alpha:]]*).*'

    trace "JENKINS_JOB_NAME = ${JENKINS_JOB_NAME}"

    if [[ ${JENKINS_JOB_NAME} =~ ${regex} ]] ; then
        
        # 2014-02-17 demx2fk3 TODO do this in a better wa
        case ${BASH_REMATCH[1]} in
            trunk)
                trace "TODO: mapping location name from trunk to pronb-developer"
                echo pronb-developer
            ;;
            *)
                echo ${BASH_REMATCH[1]}
            ;;
        esac
    fi
    
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

    trace "switching to new location \"${location}\""
    execute build newlocations ${location}
}

# side effect: change directory
setupNewWorkspace() {
    local workspace=$(getWorkspaceName) 
    execute cd "${workspace}"
    execute build setup                                                                                                
}

mustHaveValidWorkspace() {

    return

}

switchSvnServerInLocations() {
    local workspace=$(getWorkspaceName) 

    # todo

}

checkoutSubprojectDirectories() {
    local workspace=$(getWorkspaceName) 
    local project=$1
    execute build adddir "${project}"
}

createTempFile() {
    local tempfile=$(mktemp)
    GLOBAL_tempfiles=("${tempfile}" "${GLOBAL_tempfiles[@]}")
    echo ${tempfile}
}

cleanupTempFiles() {
    for file in ${GLOBAL_tempfiles[@]}
    do
        rm -rf ${file}            
    done
}

declare -a GLOBAL_tempfiles 
exit_add cleanupTempFiles
