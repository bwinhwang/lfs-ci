# REQUESTOR=${BUILD_USER}
# REQUESTOR_FIRST_NAME=${BUILD_USER_FIRST_NAME}
# REQUESTOR_LAST_NAME=${BUILD_USER_LAST_NAME}
# REQUESTOR_USERID=${BUILD_USER_ID}
# REQUESTOR_EMAIL=${BUILD_USER_EMAIL}

[[ -z ${LFS_CI_SOURCE_createworkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_build}           ]] && source ${LFS_CI_ROOT}/lib/build.sh
[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh

LFS_CI_SOURCE_special_build='$Id$'

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
                       REQUESTOR_EMAIL

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

    debug "create own revision control file"
    echo "src-fake http://fakeurl/ ${revision}" > ${WORKSPACE}/revisionstate.xml
    rawDebug ${WORKSPACE}/revisionstate.xml
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${WORKSPACE}/revisionstate.xml

    info "storing input as artifacts"
    execute mkdir -p ${workspace}/bld/bld-${buildType,,}-input/
    execute -i cp -a ${WORKSPACE}/lfs.patch ${workspace}/bld/bld-${buildType,,}-input/
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

specialBuildCreateWorkspaceAndBuild() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    execute rm -rf ${WORKSPACE}/revisions.txt
    createWorkspace
    copyArtifactsToWorkspace "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "fsmci"

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
#  @param   <none>
#  @return  <none>
uploadKnifeToStorage() {
    knifeFile=${1}
    mustExistFile ${knifeFile}

    local uploadServer=$(getConfig LFS_CI_upload_server)
    mustHaveValue "${uploadServer}" "upload server and path"

    execute rsync -avrPe ssh ${knifeFile} \
        ${uploadServer}

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

    if [[ -e ${workspace}/bld/bld-knife-input/knife.tar.gz ]] ; then
        info "extracting knife.tar.gz..."
        execute tar -xvz -C ${workspace} -f ${workspace}/bld/bld-knife-input/knife.tar.gz
    fi

    if [[ -e ${workspace}/bld/bld-knife-input/knife.patch ]] ; then
        info "applying knife.patch file..."
        execute patch -d ${workspace} < ${workspace}/bld/bld-knife-input/knife.patch
    fi

    # add more stuff here

    return
}

specialBuildUploadAndNotifyUser() {

    requiredParameters LFS_CI_ROOT 

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    mustExistFile ${workspace}/bld/bld-knife-input/knife-requestor.txt
    source ${workspace}/bld/bld-knife-input/knife-requestor.txt

    info "creating tarball with lfs load..."
    local tarOpt=$(getConfig LFS_CI_uc_special_build_package_tar_options)

    execute tar -cv ${tarOpt}                \
                --transform='s:^\./:os/:'    \
                -C ${workspace}/upload/      \
                -f ${workspace}/${label}.tar \
                .

    info "compressing lfs-knife.tar..."
    execute ${LFS_CI_ROOT}/bin/pigz ${workspace}/${label}.tar

    info "upload knife to storage"
    uploadKnifeToStorage ${workspace}/${label}.tar.gz 

    local readmeFile=${workspace}/.00_README.txt
    cat > ${readmeFile} <<EOF
/build/home/${USER}/private_builds/${label}.tar.gz
EOF

    copyFileToArtifactDirectory ${readmeFile}

    execute ${LFS_CI_ROOT}/bin/sendReleaseNote \
            -r ${readmeFile}                   \
            -t ${label}                        \
            -n                                 \
            -f ${LFS_CI_ROOT}/etc/file.cfg
    return
}



