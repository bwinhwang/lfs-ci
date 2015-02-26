#!/bin/bash
## @file uc_knife_build.sh
#  @brief usecase for create a lfs knife build
#  @details  workflow

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh
[[ -z ${LFS_CI_SOURCE_build}           ]] && source ${LFS_CI_ROOT}/lib/build.sh
[[ -z ${LFS_CI_SOURCE_uc_lfs_package}  ]] && source ${LFS_CI_ROOT}/lib/uc_lfs_package.sh

## @fn      usecase_LFS_KNIFE_BUILD_PLATFORM()
#  @brief   build a lfs knife
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_BUILD_PLATFORM() {

    requiredParameters WORKSPACE UPSTREAM_PROJECT UPSTREAM_BUILD

    local baseLabel=${KNIFE_LFS_BASELINE}

    debug "create own revision control file"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    copyFileFromBuildDirectoryToWorkspace revisionstate.xml

    # faking the branch name for workspace creation...
    LFS_CI_GLOBAL_BRANCH_NAME=$(getConfig LFS_PROD_tag_to_branch)

    if ! specialBuildisRequiredForLrc ${location} ; then
        warning "build is not required."
        exit 0
    fi

    # create a workspace

    if [[ -z ${LFS_CI_GLOBAL_BRANCH_NAME} ]] ; then
        fatal "this branch is not prepared to build knives"
    fi

    # for FSM-r4, it's have to do this in a different way..
    if [[ ${subTaskName} = "FSM-r4" ]] ; then
        case ${LFS_CI_GLOBAL_BRANCH_NAME} in
            trunk) LFS_CI_GLOBAL_BRANCH_NAME=FSM_R4_DEV ;;
            *)     # TODO: demx2fk3 2015-02-03 add check, if new location exists, otherwise no build
                   LFS_CI_GLOBAL_BRANCH_NAME=${LFS_CI_GLOBAL_BRANCH_NAME}_FSMR4 ;;
        esac
    fi
    export LFS_CI_GLOBAL_BRANCH_NAME

    createWorkspace

    copyArtifactsToWorkspace "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "fsmci"
    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    # apply patches to the workspace
    applyKnifePatches

    buildLfs

    info "upload results to artifakts share."
    createArtifactArchive

    info "build job finished."
    return
}

## @fn      usecase_LFS_KNIFE_BUILD()
#  @brief   run the usecase LFS Knife Build
#  @param   <none>
#  @return  <none>
usecase_LFS_DEVELOPER_BUILD() {

    requiredParameters DEVBUILD_LOCATION \
                       DEVBUILD_REVISION \
                       REQUESTOR_USERID 

    local currentDateTime=$(date +%Y%m%d-%H%M%S)
    local revision=${DEVBUILD_REVISION}
    local location=${DEVBUILD_LOCATION^^}
    local userid=${REQUESTOR_USERID^^}
    local label=$(printf "DEV_%s_%s_%s.%s" ${userid} ${location} ${revision} ${currentDateTime})

    specialBuildPreparation DEV ${label} ${revision} ${location} ${DEVBUILD_REVISION}

    return
}

## @fn      usecase_LFS_KNIFE_PACKAGE()
#  @brief   run the usecase lfs knife package
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_PACKAGE() {
    requiredParameters LFS_CI_ROOT WORKSPACE

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    export LFS_CI_GLOBAL_BRANCH_NAME=$(getConfig LFS_PROD_tag_to_branch)
    if [[ -z ${LFS_CI_GLOBAL_BRANCH_NAME} ]] ; then
        fatal "this branch is not prepared to build knives"
    fi

    info "running usecase LFS package"
    ci_job_package

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    mustExistFile ${workspace}/bld/bld-knife-input/knife-requestor.txt

    source ${workspace}/bld/bld-knife-input/knife-requestor.txt

    info "creating tarball with lfs load..."
    execute tar -cv \
                --transform='s:^\./:os/:' \
                -C ${workspace}/upload/ \
                -f ${workspace}/lfs-knife_${label}.tar \
                .

    info "compressing lfs-knife.tar..."
    execute ${LFS_CI_ROOT}/bin/pigz ${workspace}/lfs-knife_${label}.tar

    info "upload knife to storage"
    uploadKnifeToStorage ${workspace}/lfs-knife_${label}.tar.gz 

    local readmeFile=${WORKSPACE}/.00_README_knife_result.txt
    cat > ${readmeFile} <<EOF
eslinn10.emea.nsn-net.net:/vol/eslinn10_bin/build/build/home/lfs_knives/lfs-knife_${label}.tar.gz
EOF

    copyFileToArtifactDirectory $(basename ${readmeFile})

    execute ${LFS_CI_ROOT}/bin/sendReleaseNote -r ${WORKSPACE}/.00_README_knife_result.txt \
                                               -t ${label}                                 \
                                               -n                                          \
                                               -f ${LFS_CI_ROOT}/etc/file.cfg

    info "knife done."

    return
}

## @fn      uploadKnifeToStorage()
#  @brief   upload the knife results to the storage
#  @param   <none>
#  @return  <none>
uploadKnifeToStorage() {
    knifeFile=${1}
    mustExistFile ${knifeFile}

    execute rsync -avrPe ssh ${knifeFile} lfs_share_sync_host_espoo2:/build/home/lfs_knives/

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
