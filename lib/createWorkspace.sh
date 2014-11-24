createOrUpdateWorkspace() {

    local updateWorkspace=

    #  TODO: demx2fk3 2014-11-24 add getopt here
    while [[ $# -gt 0 ]]
    do
        case $1 in
            -u|--udpate) updateWorkspace=1  ;;
            (-*)         fatal "unrecognized option $1" ;;
        esac
        shift;
    done

    local location=$(getLocationName)
    mustHaveLocationName

    local target=$(getTargetBoardName)
    mustHaveTargetBoardName

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "productName"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local taskName=$(getTaskNameFromJobName)
    local subTaskName=$(getSubTaskNameFromJobName)
    trace "taskName is ${taskName} / ${subTaskName}"
    debug "create workspace for ${location} / ${target} in ${workspace}"

    if [[ -f ${workspace}/.build_workdir && ! -z ${updateWorkspace} ]] ; then
        updateWorkspace
    else
        createWorkspace            
    fi

    mustHaveValidWorkspace

    mustHaveLocalSdks
    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}

    return 0

}

updateWorkspace() {
    local location=$(getLocationName)
    mustHaveLocationName

    local target=$(getTargetBoardName)
    mustHaveTargetBoardName

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "productName"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace
    mustHaveCleanWorkspace

    local taskName=$(getTaskNameFromJobName)
    local subTaskName=$(getSubTaskNameFromJobName)

    # we want the latest revision state file, so we clean it up first
    execute rm -rf ${WORKSPACE}/revisions.txt

    if ! execute -i ${build} updateall ; then
        # FALLBACK: updating the workspace failed, we will recreate the workspace
        warning "updating the workspace failed, removing and recreating workspace now..."
        createWorkspace
    else
        info "workspace update was successful"
        updateWorkspace
    fi

    mustHaveLocalSdks
    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}

    return
}

createWorkspace() {
    local location=$(getLocationName)
    mustHaveLocationName

    local target=$(getTargetBoardName)
    mustHaveTargetBoardName

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "productName"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    local taskName=$(getTaskNameFromJobName)
    local subTaskName=$(getSubTaskNameFromJobName)

    setupNewWorkspace
    mustHaveWritableWorkspace
    switchSvnServerInLocations ${location}

    local srcDirectory=$(getConfig LFS_CI_UC_build_subsystem_to_build)
    mustHaveValue "${srcDirectory}" "src directory"
    info "requested source directory: ${srcDirectory}"

    local revision=$(latestRevisionFromRevisionStateFile)
    mustHaveValue "${revision}" "revision from revision state file"

    checkoutSubprojectDirectories ${srcDirectory} ${revision}

    buildTargets=$(requiredSubprojectsForBuild)
    mustHaveValue "${buildTargets}" "build targets"
    info "using src-dirs: ${buildTargets}"

    local amountOfTargets=$(echo ${buildTargets} | wc -w)
    local counter=0

    for src in ${buildTargets} ; do

        local revision=$(latestRevisionFromRevisionStateFile)
        mustHaveValue ${revision} "revision from revision state file"

        counter=$( expr ${counter} + 1 )
        info "(${counter}/${amountOfTargets}) checking out sources for ${src} rev ${revision:-latest}"
        checkoutSubprojectDirectories "${src}" "${revision}"
    done 

    return
}

latestRevisionFromRevisionStateFile() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD WORKSPACE


    if [[ ! -e ${WORKSPACE}/revisions.txt ]] ; then
        copyRevisionStateFileToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}
    fi

    local revision=
    if [[ -r "${WORKSPACE}/revisions.txt" ]] ; then
        # TODO: demx2fk3 2014-06-25 stupid bug: adddir will not update to a higher revision, 
        #                           if the src-directory already exists...
        # revision=$(grep "^${src} " ${WORKSPACE}/revisions.txt | cut -d" " -f3)
        revision=$(cut -d" " -f 3 ${WORKSPACE}/revisions.txt | sort -n -u | tail -n 1)
    fi

    echo ${revision}
}

requiredSubprojectsForBuild() {

    local onlySourceDirectory=$(getConfig LFS_CI_UC_build_onlySourceDirectories)
    if [[ ${onlySourceDirectory} ]] ; then
        buildTargets=${onlySourceDirectory}
    else
        info "getting required src-directories for ${srcDirectory}"
        execute "${build} -C ${srcDirectory} src-list_${productName}_${subTaskName}"
        local buildTargets=$(${build} -C ${srcDirectory} src-list_${productName}_${subTaskName}) 
        mustHaveValue "${buildTargets}" "no build targets configured"
        buildTargets="$(getConfig LFS_CI_UC_build_additionalSourceDirectories) ${buildTargets}"
    fi

    echo ${buildTargets}
}
