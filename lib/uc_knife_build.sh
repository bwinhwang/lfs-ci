#!/bin/bash
## @file uc_knife_build.sh
#  @brief usecase for create a lfs knife build
#  @details  workflow
# * triggered via WFT 
# * runnins as a Jenkins project in LFS CI
#   - INPUT
#     - name of the requestor of the knife (username, email, real name)
#     - name of the branch in BTS_SC_LFS (opt)
#     - knife.zip (opt)
#     - knife request id (from WFT) (opt)
#     - base of the knife (baseline name)
#   job parameter
#     - KNIFE: knife.tar.gz
#     - BASED_ON: - LFS
#     - 
#   - OUTPUT
#     - location (path on build share), where the LFS production is stored
#     - upload to S3
#
# * create a workspace
#   - based on baseline name
#   - or on branch name from BTS_SC_LFS
#   - we can use the existing createWorkspace function, but we have to
#     fake the revision state file with the baseline name:
#     src-bos <url> <LABEL>
#     src-kernelsources <url> <LABEL>
#     ...
#
# Limitations
#  - only on branches, which are compartible with the new CI
#
# in Jenkins 
# * jobnames
#   - LFS_KNIFE_-_knife_-_Build
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fcmd
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fspc
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_qemu
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r3_-_fsm3_octeon2
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r3_-_qemu_64
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r4_-_fsm4_axm
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r4_-_fsm4_k2
#   - LFS_KNIFE_-_knife_-_Package_-_package
#
# build names
#  - PS_LFS_OS_2015_01_0001 => 15010001
#  - FB_PS_LFS_OS_2015_01_0001 => fb15010001
#  - KNIFE_<id>_PS_LFS_OS_2015_01_0001 => knife<id>15010001
#
# Brain storming
# * we want to use as much code as possible from usecases build and package
# * we should think about to have a own configuation for a knife, which is overwriting the default values
#   (change in Config)
# * workspaces are unique
#   - /var/fpwork/${USER}/lfs-knife-workspaces/knifes.<dateTime>.<requestor>.<knifeId>
# * knife workspaces can be deleted after building (no matter if it is successful or not)

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

    # get the information from WFT (opt)
    # get the information from jenkins

    requiredParameters KNIFE_LFS_BASELINE WORKSPACE UPSTREAM_PROJECT UPSTREAM_BUILD

    local baseLabel=${KNIFE_LFS_BASELINE}

    # we have to figure out, if we need to build something.
    # e.g.: if the knife baseline is a LRC baseline, we 
    # do not need to build FSM-r2,3,4.
    # also for FSM-r4, we need a different location.
    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}" "subTaskName"

    info "baseLabel ${baseLabel}"
    info "subTaskName ${subTaskName}"
   
    # short names: stn := subTaskName
    #              bl  := baseLabel
    #
    #  results: build should be done := 1
    #           build not required   := 0
    #
    #            | stn == LRC | stn != LRC 
    # -------------------------------------
    #  bl =  LRC |      1     |      0
    # -------------------------------------
    #  bl != LRC |      0     |      1
    # -------------------------------------

    if [[ ${baseLabel} =~ LRC_LCP ]] ; then
        if [[ ${subTaskName} = LRC ]] ; then
            debug "it's a LRC build, everything is fine."
        else
            warning "Knife baseline is an LRC-baseline, but build is not required for LRC"
            exit 0
        fi
    else
        if [[ ${subTaskName} = LRC ]] ; then
            warning "Knife baseline is an LRC-baseline, but build is not required for LRC"
            exit 0
        else
            debug "it's a normal FSMr-x build, everything is fine."
        fi
    fi

    # create a workspace
    debug "create own revision control file"
    export tagName=${baseLabel}
    local svnReposUrl=$(getConfig LFS_PROD_svn_delivery_os_repos_url)
    mustExistInSubversion ${svnReposUrl}/tags/${baseLabel}/doc/scripts/ revisions.txt
    local revision=$(svnCat ${svnReposUrl}/tags/${baseLabel}/doc/scripts/revisions.txt | cut -d" " -f3 | sort -nu | tail -n 1)
    echo "src-knife ${svnReposUrl}/tags/${baseLabel} ${revision}" > ${WORKSPACE}/revisions.txt

    # faking the branch name for workspace creation...
    export LFS_CI_GLOBAL_BRANCH_NAME=$(getConfig LFS_PROD_tag_to_branch)
    if [[ -z ${LFS_CI_GLOBAL_BRANCH_NAME} ]] ; then
        fatal "this branch is not prepared to build knives"
    fi

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
usecase_LFS_KNIFE_BUILD() {

    requiredParameters KNIFE_LFS_BASELINE  KNIFE_REQUESTOR

    local currentDateTime=$(date +%Y%m%d-%H%M%S)
    local label=$(printf "KNIFE_%s.%s" ${KNIFE_LFS_BASELINE} ${currentDateTime})

    info "knife label is ${label}"
    info "knife is based on ${KNIFE_LFS_BASELINE}"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    debug "writing new label file in workspace ${workspace}"
    execute mkdir -p ${workspace}/bld/bld-fsmci-summary/
    echo ${label}              > ${workspace}/bld/bld-fsmci-summary/label
    echo ${KNIFE_LFS_BASELINE} > ${workspace}/bld/bld-fsmci-summary/oldLabel

    debug "create own revision control file"
    echo "src-foo http://fakeurl/ ${baseLabel}" > ${WORKSPACE}/revisionstate.xml
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} revisionstate.xml
    

    info "storing knife input as artifacts"
    execute mkdir -p ${workspace}/bld/bld-knife-input/
    execute -i cp -a ${WORKSPACE}/lfs.patch ${workspace}/bld/bld-knife-input/

    info "upload results to artifakts share."
    createArtifactArchive

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}<br>${KNIFE_REQUESTOR}"

    info "build preparation done."

    return
}

## @fn      usecase_LFS_KNIFE_PACKAGE()
#  @brief   run the usecase lfs knife package
#  @param   <none>
#  @return  <none>
usecase_LFS_KNIFE_PACKAGE() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    info "running usecase LFS package"
    ci_job_package

    info "creating tarball with lfs load..."
    execute tar -cv \
                --transform='s:^\./:os/:' \
                -C ${workspace}/upload/ \
                -f ${workspace}/lfs-knife.tar \
                .

#    info "adding sdk to tarball..."
#    for sdk in $(getUsedSdkVersions) ; do
#        execute tar -rv \
#                    --transform='s:^\./:sdk3/:' \
#                    -C /build/home/CI_LFS/SDKs/${sdk}/ \
#                    -f ${workspace}/lfs-knife.tar \
#                    .
#    done
    info "compressing lfs-knife.tar..."
    execute gzip ${workspace}/lfs-knife.tar

    info "upload knife to storage"
    uploadKnifeToStorage

    local readmeFile=${WORKSPACE}/.00_README_knife_result.txt
    cat > ${readmeFile} <<EOF
Dear User,

The knife results are located in ...

Your LFS SCM Team
EOF

    copyFileToArtifactDirectory $(basename ${readmeFile})

    info "knife done."

    return
}

## @fn      uploadKnifeToStorage()
#  @brief   upload the knife results to the storage
#  @param   <none>
#  @return  <none>
uploadKnifeToStorage() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    knifeFile=${workspace}/lfs-knife.tar.gz
    mustExistFile ${knifeFile}

    warning "upload is not implemented"
    # execute ncftpput -m -C mailarchiv.emea.nsn-net.net ${knifeFile} /public/BernhardMinks/knife

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
