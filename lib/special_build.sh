#!/bin/bash
## @file special_build.sh
#  @brief functions for special builds like knife build and developer build
#  @details the following environment variables are used from a jenkins plugin
#           REQUESTOR=${BUILD_USER}
#           REQUESTOR_FIRST_NAME=${BUILD_USER_FIRST_NAME}
#           REQUESTOR_LAST_NAME=${BUILD_USER_LAST_NAME}
#           REQUESTOR_USERID=${BUILD_USER_ID}
#           REQUESTOR_EMAIL=${BUILD_USER_EMAIL}

[[ -z ${LFS_CI_SOURCE_createworkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_build}           ]] && source ${LFS_CI_ROOT}/lib/build.sh
[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_amazons3}        ]] && source ${LFS_CI_ROOT}/lib/amazons3.sh
[[ -z ${LFS_CI_SOURCE_git}             ]] && source ${LFS_CI_ROOT}/lib/git.sh

LFS_CI_SOURCE_special_build='$Id$'

## @fn      specialBuildPreparation()
#  @brief   prepare the build 
#  @param   {buildType}    type of the build (e.g. DEV, KNIFE)
#  @param   {label}        name of the build label
#  @param   {revision}     a revision number
#  @param   {location}     the name of the location
#  @return  <none>
specialBuildPreparation() {

    local buildType=${1}
    mustHaveValue "${buildType}" "build type"

    local label=${2}
    mustHaveValue "${label}" "label"

    local revision=${3} # or label name
    mustHaveValue "${revision}" "revision"

    local location=${4}
    mustHaveValue "${location}" "location"

    requiredParameters WORKSPACE            \
                       JOB_NAME             \
                       BUILD_NUMBER         \
                       REQUESTOR            \
                       REQUESTOR_FIRST_NAME \
                       REQUESTOR_LAST_NAME  \
                       REQUESTOR_USERID     \
                       REQUESTOR_EMAIL      \
                       LFS_BUILD_FSMR2      \
                       LFS_BUILD_FSMR3      \
                       LFS_BUILD_FSMR4      \
                       LFS_BUILD_LRC

    debug "input parameter: buildType ${buildType}"
    debug "input parameter: label ${label}"
    debug "input parameter: revision ${revision}"
    debug "input parameter: location ${location}"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    info "build label is ${label}"
    info "build is based on ${location}@${revision}"

    debug "writing new label file in workspace ${workspace}"
    execute mkdir -p ${workspace}/bld/bld-fsmci-summary/
    echo ${label}    > ${workspace}/bld/bld-fsmci-summary/label
    echo ${location} > ${workspace}/bld/bld-fsmci-summary/location
    echo ${revision} > ${workspace}/bld/bld-fsmci-summary/svnrevision

    createFingerprintFile

    debug "create own revision control file"
    echo "src-fake http://fakeurl/ ${revision}" > ${WORKSPACE}/revisionstate.xml
    rawDebug ${WORKSPACE}/revisionstate.xml
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${WORKSPACE}/revisionstate.xml

    info "storing input as artifacts"
    execute mkdir -p ${workspace}/bld/bld-${buildType,,}-input/
    execute -i cp -a ${WORKSPACE}/lfs.patch ${workspace}/bld/bld-${buildType,,}-input/
    cat > ${workspace}/bld/bld-${buildType,,}-input/lfs_build.txt <<EOF
LFS_BUILD_FSMR2=${LFS_BUILD_FSMR2}
LFS_BUILD_FSMR3=${LFS_BUILD_FSMR3}
LFS_BUILD_FSMR4=${LFS_BUILD_FSMR4}
LFS_BUILD_LRC=${LFS_BUILD_LRC}
EOF
    rawDebug ${workspace}/bld/bld-${buildType,,}-input/lfs_build.txt

    cat > ${workspace}/bld/bld-${buildType,,}-input/requestor.txt <<EOF
REQUESTOR="${REQUESTOR}"
REQUESTOR_FIRST_NAME="${REQUESTOR_FIRST_NAME}"
REQUESTOR_LAST_NAME="${REQUESTOR_LAST_NAME}"
REQUESTOR_USERID="${REQUESTOR_USERID}"
REQUESTOR_EMAIL="${REQUESTOR_EMAIL}"
EOF
    rawDebug ${workspace}/bld/bld-${buildType,,}-input/requestor.txt

    info "upload results to artifakts share."
    createArtifactArchive

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}<br>${REQUESTOR}"

    info "build preparation done."
    return
}

## @fn      specialBuildisRequiredForLrc()
#  @brief   checks, if the build requires a LRC build
#  @param   {location}    the name of the location
#  @param   <none>
#  @return  <none>
specialBuildisRequiredForLrc() {
    local location=${1}
    mustHaveValue "${location}" "location"

    # we have to figure out, if we need to build something.
    # e.g.: if the knife baseline is a LRC baseline, we
    # do not need to build FSM-r2,3,4.
    # also for FSM-r4, we need a different location.
    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}" "subTaskName"

    info "location ${location}"
    info "subTaskName ${subTaskName}"

    # short names: stn := subTaskName
    #              loc := location
    #
    #  results: build should be done := 1
    #           build not required   := 0
    #
    #             | stn == LRC | stn != LRC
    # --------------------------------------
    #  loc = LRC  |      1     |      0
    # --------------------------------------
    #  loc != LRC |      0     |      1
    # --------------------------------------


    if [[ ${location} =~ LRC ]] ; then
        if [[ ${subTaskName} = LRC ]] ; then
            debug "it's a LRC build, everything is fine."
        else
            warning "Build locaation is an LRC-location, but build is not required for LRC"
            return 1
        fi
    else
        if [[ ${subTaskName} = LRC ]] ; then
            warning "Build location is an LRC-location, but build is not required for LRC"
            return 1
        else
            debug "it's a normal FSMr-x build, everything is fine."
        fi
    fi

    return 0
}

## @fn      specialBuildisRequiredSelectedByUser(  )
#  @brief   checks, if the build is requested by the user (via jenkins input)
#  @param   {buildType}    type of the build, values DEV or KNIFE
#  @return  <none>
specialBuildisRequiredSelectedByUser() {
    local buildType=${1}
    mustHaveValue "${buildType}" "build type"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}" "subTaskName"

    mustExistFile ${workspace}/bld/bld-${buildType,,}-input/lfs_build.txt
    rawDebug ${workspace}/bld/bld-${buildType,,}-input/lfs_build.txt
    source ${workspace}/bld/bld-${buildType,,}-input/lfs_build.txt

    if [[ ${LFS_BUILD_FSMR2} != true && ${subTaskName} = "FSM-r2" ]] ; then
        warning "build FSM-r2 was not selected by user"
        return 1
    fi
    if [[ ${LFS_BUILD_FSMR3} != true && ${subTaskName} = "FSM-r3" ]] ; then
        warning "build FSM-r3 was not selected by user"
        return 1
    fi
    if [[ ${LFS_BUILD_FSMR4} != true && ${subTaskName} = "FSM-r4" ]] ; then
        warning "build FSM-r4 was not selected by user"
        return 1
    fi
    if [[ ${LFS_BUILD_LRC} != true && ${subTaskName} = "LRC" ]] ; then
        warning "build LRC was not selected by user"
        return 1
    fi

    return 0
}

## @fn      specialBuildCreateWorkspaceAndBuild()
#  @brief   create the workspaces and build the special build (knife or developer build)
#  @param   {buildType}    type of the build, values DEV or KNIFE
#  @return  <none>
specialBuildCreateWorkspaceAndBuild() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    local buildType=$1
    mustHaveValue "${buildType}" "build type"

    local workspaces=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    copyArtifactsToWorkspace "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}"

    mustHaveLocationForSpecialBuild
    local location=${LFS_CI_GLOBAL_BRANCH_NAME}

    if ! specialBuildisRequiredForLrc ${location} ; then
        warning "build is not required."
        exit 0
    fi
    if ! specialBuildisRequiredSelectedByUser ${buildType} ; then
        warning "build is not required."
        exit 0
    fi

    export LFS_CI_GLOBAL_BRANCH_NAME=${location}

    # createWorkspace will copy the revision state file from the upstream job
    execute rm -rf ${WORKSPACE}/revisions.txt
    createWorkspace
    copyArtifactsToWorkspace "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    # apply patches to the workspace
    applyKnifePatches
    buildLfs
    createArtifactArchive

    return
}


## @fn      uploadKnifeToStorage()
#  @brief   upload the knife results to the storage
#  @param   {knifeFile} output file, which should be uploaded to storage
#  @return  <none>
uploadKnifeToStorage() {
    knifeFile=${1}
    mustExistFile ${knifeFile}

    local uploadServer=$(getConfig LFS_CI_upload_server)
    mustHaveValue "${uploadServer}" "upload server and path"

    s3PutFile ${knifeFile} ${uploadServer}
    s3SetAccessPublic ${uploadServer}/$(basename ${knifeFile})

    return
}

## @fn      applyKnifePatches()
#  @brief   apply the patches from the knife input to the workspace
#  @param   <none>
#  @return  <none>
applyKnifePatches() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    info "applying patches to workspace..."

    for type in knife dev ; do
        if [[ -e ${workspace}/bld/bld-${type}-input/lfs.tar.gz ]] ; then
            info "extracting lfs.tar.gz..."
            execute tar -xvz -C ${workspace} -f ${workspace}/bld/bld-${type}-input/lfs.tar.gz
        fi

        if [[ -e ${workspace}/bld/bld-${type}-input/lfs.patch ]] ; then
            info "applying lfs.patch file..."

            # apply patch only on files which exists in workspace
            for fileInPatch in $(execute -n lsdiff ${workspace}/bld/bld-${type}-input/lfs.patch) ; do
                info "matching file ${fileInPatch}"

                # we are checking for the existance of the basedirectory (src-foobar). If the directory exists,
                # we can apply the patch - also for new files.
                local dirName=$(dirname ${fileInPatch} | cut -d/ -f1)
                mustHaveValue "${dirName}" "dir name (src-dir) from ${fileInPatch}"
                [[ -d ${workspace}/${dirName} ]] || continue

                info "applying patch ${fileInPatch}"
                local tmpPatchFile=$(createTempFile)
                execute -n filterdiff -i ${fileInPatch} ${workspace}/bld/bld-${type}-input/lfs.patch > ${tmpPatchFile}
                rawDebug ${tmpPatchFile}
                execute patch -p0 -d ${workspace} < ${tmpPatchFile}
            done                     
        fi
    done

    # add more stuff here

    return
}

## @fn      specialBuildUploadAndNotifyUser()
#  @brief   upload the build result to the storage and notify the user
#  @param   <none>
#  @return  <none>
specialBuildUploadAndNotifyUser() {
    requiredParameters LFS_CI_ROOT LFS_CI_CONFIG_FILE

    local buildType=$1
    mustHaveValue "${buildType}" "build type"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "${buildType,,} fsmci"

    local uploadServer=$(getConfig LFS_CI_upload_server_http)
    mustHaveValue "${uploadServer}" "upload server http"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    mustExistFile ${workspace}/bld/bld-${buildType,,}-input/requestor.txt
    rawDebug ${workspace}/bld/bld-${buildType,,}-input/requestor.txt
    source ${workspace}/bld/bld-${buildType,,}-input/requestor.txt
    export REQUESTOR REQUESTOR_FIRST_NAME REQUESTOR_LAST_NAME REQUESTOR_USERID REQUESTOR_EMAIL

    local readmeFile=${workspace}/.00_README.txt
    execute touch ${readmeFile}
    local resultFiles="$(getConfig LFS_CI_uc_special_build_package_result_files)"

    info "requested result files are ${resultFiles}"

    for resultFile in ${resultFiles} ; do
        info "creating tarball ${resultFile} with lfs load..."
        local tarOpt="$(getConfig LFS_CI_uc_special_build_package_result_files_tar_options -t file:${resultFile})"
        local inputFiles="$(getConfig LFS_CI_uc_special_build_package_result_files_input_files -t file:${resultFile})"
        local outputFilePostfix=$(getConfig LFS_CI_uc_special_build_package_result_files_output_file -t file:${resultFile})

        local outputFile=${label}${outputFilePostfix}.tgz
        debug "create tar ${outputFile}"
        execute tar -cv ${tarOpt}                                  \
                    --transform='s:^\./:os/:'                      \
                    -C ${workspace}/upload/                        \
                    -f ${workspace}/${outputFile}                  \
                    --use-compress-program=${LFS_CI_ROOT}/bin/pigz \
                    ${inputFiles}

        info "upload file ${outputFile} to storage ${uploadServer}"
        uploadKnifeToStorage ${workspace}/${outputFile}

        echo ${uploadServer}/${outputFile} >> ${readmeFile} 

    done

    copyFileToArtifactDirectory ${readmeFile}

    execute ${LFS_CI_ROOT}/bin/sendReleaseNote \
            -r ${readmeFile}                   \
            -t ${label}                        \
            -n                                 \
            -f ${LFS_CI_CONFIG_FILE}
    return
}


## @fn      mustHaveLocationForSpecialBuild()
#  @brief   ensures, that there is a location for a special build
#  @param   <none>
#  @return  <none>
mustHaveLocationForSpecialBuild() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    # we need to fake the branch for the layer below...
    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "fsmci"

    # fakeing the branch name for workspace creation...
    local location=$(cat ${workspace}/bld/bld-fsmci-summary/location)
    mustHaveValue "${location}" "location"
    export LFS_CI_GLOBAL_BRANCH_NAME=${location}

    return
}

## @fn      specialPkgpoolPrepareBuild()
#  @brief   prepare the workspace for a git pkgpool build
#  @param   {buildType}    type of the build (e.g. DEV, KNIFE)
#  @return  <none>
specialPkgpoolPrepareBuild() {
    requiredParameters WORKSPACE UPSTREAM_PROJECT UPSTREAM_BUILD

    local buildType=$1
    mustHaveValue "${buildType}" "build type"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    mustHaveLocationForSpecialBuild
    local locationName=$(getLocationName)
    mustHaveLocationName

    local svnUrlsToUpdate=$(getConfig PKGPOOL_PROD_update_dependencies_svn_url)
    mustHaveValue "${svnUrlsToUpdate}" "svn urls for pkgpool"
    local revisionFileInSvn=$(dirname ${svnUrlsToUpdate})/src/gitrevision
    info "revisionFileInSvn ${revisionFileInSvn}"
    local svnRevision=$(cat ${workspace}/bld/bld-fsmci-summary/svnrevision)
    info "svnRevision ${svnRevision}"
    local gitRevision=$(svnCat -r ${svnRevision} ${revisionFileInSvn}@${svnRevision})
    info "gitRevision ${gitRevision}"

    local gitUpstreamRepos=$(getConfig PKGPOOL_git_repos_url)
    mustHaveValue "${gitUpstreamRepos}" "git upstream repos url"

    local gitWorkspace=${WORKSPACE}/src

    copyArtifactsToWorkspace "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}"

    # cleanup old workspace from git
    execute rm -rf ${WORKSPACE}/src

    # clone git repos
    gitClone ${gitUpstreamRepos} ${WORKSPACE}/src

    # switch branch
    cd ${WORKSPACE}/src
    gitCheckout ${gitRevision}
    gitReset --hard

    for fileInPatch in $(execute -n lsdiff ${workspace}/bld/bld-${buildType}-input/lfs.patch) ; do
        local pathName=$(cut -d/ -f1,2 <<< ${fileInPatch})
        case ${pathName} in
            src-*) : ;;
            src/*) 
                   info "updating submodule ${pathName}"
                   gitSubmodule update ${pathName}

                   info "applying patch ${fileInPatch}"
                   local tmpPatchFile=$(createTempFile)
                   execute -n filterdiff -i ${fileInPatch} ${workspace}/bld/bld-${buildType}-input/lfs.patch > ${tmpPatchFile}
                   rawDebug ${tmpPatchFile}
                   execute patch -p0 -d ${workspace} < ${tmpPatchFile}
            ;;
        esac
    done

    return
}

specialPkgpoolCollectArtifacts() {
    requiredParameters LFS_CI_ROOT UPSTREAM_PROJECT UPSTREAM_BUILD

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    info "creating artifacts of pkgpool"
    cd ${workspace}
    execute tar cv --use-compress-program ${LFS_CI_ROOT}/bin/pigz --file ${workspace}/bld-pkgpool-artifacts.tar.gz --transform='s:^\pool/:pkgpool/:' pool/
    copyFileToArtifactDirectory ${workspace}/bld-pkgpool-artifacts.tar.gz ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}

    return
}
