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

    createFingerprintFile

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

## @fn      specialBuildCreateWorkspaceAndBuild()
#  @brief   create the workspaces and build the special build (knife or developer build)
#  @param   <none>
#  @return  <none>
specialBuildCreateWorkspaceAndBuild() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    local workspaces=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustHaveLocationForSpecialBuild
    local location=${LFS_CI_GLOBAL_BRANCH_NAME}

    if ! specialBuildisRequiredForLrc ${location} ; then
        warning "build is not required."
        exit 0
    fi

    export LFS_CI_GLOBAL_BRANCH_NAME=${location}

    # createWorkspace will copy the revision state file from the upstream job
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
            # error will be ignored, if the patch file will not apply without problems
            execute -i patch -p0 -d ${workspace} < ${workspace}/bld/bld-${type}-input/lfs.patch
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
    requiredParameters LFS_CI_ROOT 

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
            -f ${LFS_CI_ROOT}/etc/file.cfg
    return
}


## @fn      mustHaveLocationForSpecialBuild()
#  @brief   ensures, that there is a location for a special build
#  @param   <none>
#  @return  <none>
mustHaveLocationForSpecialBuild() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    # we need to fake the branch for the layer below...
    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "fsmci"

    # fakeing the branch name for workspace creation...
    local location=$(cat ${workspace}/bld/bld-fsmci-summary/location)
    mustHaveValue "${location}" "location"

    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}" "sub task name"

    export LFS_CI_GLOBAL_BRANCH_NAME=${location}
    return
}

## @fn      cleanupS3Storage()
#  @brief   cleanup old builds from s3 storage
#  @param   {bucketName}    name of the bucket
#  @return  <none>
cleanupS3Storage() {
    local bucketName=$1
    mustHaveValue "${bucketName}" "bucket name"

    local daysNotToDelete=$(createTempFile)
    date +%Y-%m-%d --date="0 days ago"  > ${daysNotToDelete}
    date +%Y-%m-%d --date="1 days ago" >> ${daysNotToDelete}
    date +%Y-%m-%d --date="2 days ago" >> ${daysNotToDelete}
    date +%Y-%m-%d --date="3 days ago" >> ${daysNotToDelete}

    local listToDelete=$(createTempFile)
    for file in $(s3List s3://${bucketName} | grep -v -f ${daysNotToDelete} | cut -d" " -f 4-) ; do
        info "removing ${file} from s3://${bucketName}"
        s3RemoveFile ${file}
    done
    return
}
