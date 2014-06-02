#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh

## @fn      ci_job_build()
#  @brief   usecase job ci build
#  @details the use case job ci build makes a clean build
#  @param   <none>
#  @return  <none>
ci_job_build() {

    info "creating the workspace..."
    _createWorkspace

    info "building targets..."
    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label}

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    info "subTaskName is ${subTaskName}"

    case ${subTaskName} in
        *FSMDDALpdf*) _build_fsmddal_pdf ;;
        *Summary*)    _build_version     ;;
        *)            _build             ;;
    esac

    info "upload results to artifakts share."
    createArtifactArchive

    info "build job finished."
    return
}

## @fn      ci_job_build_version()
#  @brief   usecase which creates the version label
#  @details the usecase get the last label name from the last successful build and calculates
#           a new label name. The label name will be stored in a file and be artifacted.
#           The downstream jobs will use this artifact.
#  @param   <none>
#  @return  <none>
ci_job_build_version() {
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName

    local serverPath=$(getConfig jenkinsMasterServerPath)

    info "workspace is ${workspace}"

    mustHaveNextLabelName
    local label=$(getNextReleaseLabel)
    mustHaveValue ${label}

    local jobDirectory=${serverPath}/jobs/${JOB_NAME}/lastSuccessful/ 
    local oldLabel=$(runOnMaster "test -d ${jobDirectory} && grep ${label} ${jobDirectory}/label 2>/dev/null")

    info "old label ${oldLabel} from ${jobDirectory} on master"
    local postfix="00"

    if [[ "${oldLabel}" != "" ]] ; then
        local tmp=$(echo ${oldLabel} | sed "s/.*-ci0*\(.*\)/\1/")
        local newPostfix=$(( tmp + 1 ))
        postfix=$(printf "%02d" ${newPostfix})

        info "calculated new postfix for label ${postfix}"
    fi

    newCiLabel="${label}-ci${postfix}"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${newCiLabel}"

    debug "writing new label file in workspace ${workspace}"
    execute mkdir -p     ${workspace}/bld/bld-fsmci-summary
    echo ${newCiLabel} > ${workspace}/bld/bld-fsmci-summary/label

    debug "writing new label file in ${serverPath}/jobs/${JOB_NAME}/builds/${BUILD_NUMBER}/label"
    executeOnMaster "echo ${newCiLabel} > ${serverPath}/jobs/${JOB_NAME}/builds/${BUILD_NUMBER}/label"

    info "upload results to artifakts share."
    createArtifactArchive

    return
}

## @fn      _build_fsmddal_pdf()
#  @brief   creates the FSMDDAL.pdf file
#  @param   <none>
#  @return  <none>
_build_fsmddal_pdf() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    info "workspace is ${workspace}"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label}

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${newCiLabel}"

    cd ${workspace}
    execute build -C src-fsmifdd -L src-fsmifdd.log defcfg

    local tmpDir=$(createTempDirectory)
    execute mkdir -p ${tmpDir}/ddal/
    execute cp -r ${workspace}/bld/bld-fsmifdd-defcfg/results/include ${tmpDir}/ddal/

    execute tar -C   ${tmpDir} \
                -czf ${workspace}/src-fsmpsl/src/fsmddal.d/fsmifdd.tgz \
                ddal

    echo ${label} > ${workspace}/src-fsmpsl/src/fsmddal.d/label
    execute make -j -C ${workspace}/src-fsmpsl/src/fsmddal.d/ LABEL=${label}

    # fixme
    local destinationDir=${workspace}/bld/bld-fsmddal-doc/results/doc/
    execute mkdir -p ${destinationDir}
    execute cp ${workspace}/src-fsmpsl/src/fsmddal.d/FSMDDAL.pdf ${destinationDir}
    execute rm -rf ${workspace}/bld/bld-fsmifdd-defcfg

    return
}

## @fn      _build()
#  @brief   make the build
#  @details make the real build. The required build targets / configs will be determinates by
#           sortbuildsfromdependencies. This creates a list with subsystems - configs in the
#           correct order. After this, it calls the build script and executes the build.
#  @todo    replace the sortbuildsfromdependencies with the new implemtation,
#           introduce the new syntax for sortbuildsfromdependencies.
#  @param   <none>
#  @return  <none>
_build() {
    local cfgFile=$(createTempFile)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local target=$(getTargetBoardName)
    mustHaveTargetBoardName

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label}

    cd ${workspace}
    info "creating temporary makefile"
    ${LFS_CI_ROOT}/bin/sortBuildsFromDependencies ${target} makefile ${label} > ${cfgFile}

    rawDebug ${cfgFile}

    local makeTarget=$(getConfig subsystem)-${target}

    info "executing all targets in parallel with ${makeTarget} and label=${label}"
    execute make -f ${cfgFile} ${makeTarget} 

    execute mkdir -p ${workspace}/bld/bld-sdk-summary/
    execute rm -f ${workspace}/bld/bld-sdk-summary/sdks

    # storing sdk labels for later use in a artifact file.
    foreach sdk in $(ls ${workspace}/bld/sdk*) ; do
        [[ -e ${sdk} ]] || continue
        readlink ${sdk} >> ${workspace}/bld/bld-sdk-summary/sdks
    done

#     sortbuildsfromdependencies ${target} > ${cfgFile}
#     rawDebug ${cfgFile}
# 
#     local amountOfTargets=$(wc -l ${cfgFile} | cut -d" " -f1)
#     local counter=0
# 
#     while read SRC CFG
#     do
#         counter=$( expr ${counter} + 1 )
#         info "(${counter}/${amountOfTargets}) building ${CFG} from ${SRC}..."
#         execute build -C ${SRC} ${CFG} 
#     done <${cfgFile}

    return 0
}

## @fn      _createWorkspace()
#  @brief   create a new workspace for the project
#  @details this method is very huge. It creates a new workspace for a projects.
#           this includes several steps:
#           * create a new directory                             (build setup)
#           * cleanup the old workspace if exists
#           * switch to the correct location (aka branch)        (build newlocations)
#           * copy build artifacts from the upstream project if exists
#           * apply patches to the workspace
#           * get the list of required subsystem
#           * check out the subsystem from svn                   (build adddir)
#  @param   <none>
#  @return  <none>
_createWorkspace() {

    local location=$(getLocationName)
    mustHaveLocationName

    local target=$(getTargetBoardName)
    mustHaveTargetBoardName

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    local taskName=$(getTaskNameFromJobName)
    local subTaskName=$(getSubTaskNameFromJobName)
    trace "taskName is ${taskName} / ${subTaskName}"
    debug "create workspace for ${location} / ${target} in ${workspace}"

    local build="build -W \"${workspace}\""

    debug "creating a new workspace in \"${workspace}\""
    setupNewWorkspace

    switchToNewLocation ${location}

    if grep -q "ulm" <<< ${NODE_LABELS} ; then
        # change from svne1 to ulmscmi
        switchSvnServerInLocations
    fi

    mustHaveValidWorkspace

    local srcDirectory=$(getConfig "subsystem")
    if [[ ! "${srcDirectory}" ]] ; then
        error "no srcDirectory found (subsystem)"
        exit 1;
    fi
    info "requested source directory: ${srcDirectory}"

    if grep -q "ulm" <<< ${NODE_LABELS} ; then
        preCheckoutPatchWorkspace
    fi

    info "getting dependencies for ${srcDirectory}"
    local buildTargets=$(${LFS_CI_ROOT}/bin/getDependencies ${srcDirectory} 2>/dev/null )
    if [[ ! "${buildTargets}" ]] ; then
        error "no build targets configured"
        exit 1;
    fi

    buildTargets="$(getConfig additionalSourceDirectories) ${buildTargets}"

    local onlySourceDirectory=$(getConfig onlySourceDirectories)
    if [[ ${onlySourceDirectory} ]] ; then
        buildTargets=${onlySourceDirectory}
    fi

    local revision=
    if [[ -r "${WORKSPACE}/revisions.txt" ]] ; then
        info "using revision from revisions.txt file"
        # TODO: demx2fk3 2014-04-08 add handling here
        revision=
    fi

    info "using src-dirs: ${buildTargets}"

    local amountOfTargets=$(echo ${buildTargets} | wc -w)
    local counter=0

    for src in ${buildTargets} ; do

        counter=$( expr ${counter} + 1 )
        info "(${counter}/${amountOfTargets}) checking out sources for ${src}"
        checkoutSubprojectDirectories "${src}" "${revision}"

    done

    mustHaveLocalSdks
    mustHaveBuildArtifactsFromUpstream

    postCheckoutPatchWorkspace

    return 0
}

## @fn      postCheckoutPatchWorkspace()
#  @brief   apply patches before the checkout of the workspace to the workspace
#  @param   <none>
#  @return  <none>
preCheckoutPatchWorkspace() {
    _applyPatchesInWorkspace "${JOB_NAME}/preCheckout/"
    _applyPatchesInWorkspace "common/preCheckout/"
    return
}

## @fn      postCheckoutPatchWorkspace()
#  @brief   apply patches after the checkout of the workspace to the workspace
#  @param   <none>
#  @return  <none>
postCheckoutPatchWorkspace() {
    _applyPatchesInWorkspace "${JOB_NAME}/postCheckout/"
    _applyPatchesInWorkspace "common/postCheckout/"
    return
}

## @fn      _applyPatchesInWorkspace()
#  @brief   apply patches to the workspace, if exist one for the directory
#  @details in some cases, it's required to apply a patch to the workspace to
#           change some "small" issue in the workspace, e.g. change the svn server
#           from the master svne1 server to the slave ulisop01 server.
#  @param   <none>
#  @return  <none>
_applyPatchesInWorkspace() {

    local patchPath=$@

    if [[ -d "${LFS_CI_ROOT}/patches/${patchPath}" ]] ; then
        for patch in "${LFS_CI_ROOT}/patches/${patchPath}/"* ; do
            [[ ! -f "${patch}" ]] && continue
            info "applying post checkout patch $(basename \"${patch}\")"
            patch -p0 < "${patch}" || exit 1
        done
    fi

    return
}

## @fn      mustHaveLocalSdks()
#  @brief   ensure, that the "links to share" in bld are pointing to
#           a local directory
#  @detail  if there is a link in bld directory to the build share,
#           the method will trigger the copy of this directory to the local
#           directory
#  @param   <none>
#  @return  <none>
mustHaveLocalSdks() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    debug "checking for links in bld"

    for bld in ${workspace}/bld/*
    do
        [[ -e ${bld} ]] || continue
        local pathToSdk=$(readlink ${bld})
        local tag=$(basename ${pathToSdk})
        local subsystem=$(basename ${bld})
        local localCacheDir=${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/${subsystem}

        info "checking for ${subsystem} / ${tag} on local disk"

        if [[ ! -d ${localCacheDir}/${tag} ]] ; then
            synchroniceToLocalPath ${bld}
        fi

        execute rm -rf ${bld}
        execute ln -sf ${localCacheDir}/${tag} ${bld}
    done

    return
}

## @fn      synchroniceToLocalPath( localPath )
#  @brief   syncronice the given local path from there to the local cache directory
#  @details in bld, there are links to the build share. We want to avoid using build
#           share, because it's to slow. So we are rsyncing the directories from the
#           share to a local directory.
#           There are some safties active to avoid problems during syncing.
#  @param   {localPath}    local bld path
#  @return  <none>
synchroniceToLocalPath() {
    local localPath=$1
    local remotePath=$(readlink ${localPath})
    local subsystem=$(basename ${localPath})
    local tag=$(basename ${remotePath})
    local serverName=$(getConfig linseeUlmServer)

    requiredParameters LFS_CI_SHARE_MIRROR

    local localCacheDir=${LFS_CI_SHARE_MIRROR}/${USER}/lfs-ci-local/${subsystem}
    if [[ ${subsystem} == "pkgpool" ]] ; then
        local rsync_opts=-L
    fi        

    if [[ ! -e ${localCacheDir}/${tag} ]] ; then
        progressFile=${localCacheDir}/data/${tag}.in_progress

        sleep $(( RANDOM % 60 ))

        if [[ ! -e ${progressFile} ]] ; then

            info "synchronice ${subsystem}/${tag} to local filesystem"

            execute mkdir -p ${localCacheDir}/data
            execute touch ${progressFile}

            execute rsync --archive --numeric-ids --delete-excluded --ignore-errors \
                --hard-links --sparse --exclude=.svn --rsh=ssh                      \
                ${rsync_opts} \
                ${serverName}:${remotePath}/                                   \
                ${localCacheDir}/data/${tag}/

            execute ln -sf data/${tag} ${localCacheDir}/${tag}
            execute rm -f ${progressFile}
        else
            info "waiting for ${tag} on local filesystem"
            # 2014-03-12 demx2fk3 TODO make this configurable
            sleep 60
            synchroniceToLocalPath ${localPath}
        fi
    fi

    return
}
