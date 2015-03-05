#!/bin/bash
## @file    uc_build.sh
#  @brief   usecase build
#  @details the build usecase for lfs, ltk and uboot.
#
#  The build is splitted into several sub jobs - one for each architecutre (e.g. FSM-r2 fcmd).
#  All the sub jobs are run in parallel and are independend from each other. 
#  The sub jobs are triggerd by the main build job (function ci_job_build_version). 
#  The main build job has the following tasks:
#  - create the version number for the build
#  - trigger the sub jobs (via jenkins)
#  The main build job will the the state of the sub jobs. So if one of the sub jobs is failing,
#  the main build job will also fail. If all sub jobs are green, the main build job will be also green.
#
#  naming for the main build job:
#  - LFS_CI_-_trunk_-_Build
# 
# Each sub build job has the following tasks:
#  - get the artifacts from the main build job (version number)
#  - get the revision number from revision state files
#  - do the build
#     <pre>
#     # path of the CI scripting
#     export LFS_CI_ROOT=/ps/lfs/ci
#     # product name, LFS or UBOOT
#     product=LFS
#     # module name (FSM-r2, FSM-r3, FSM-r4 or LRC)
#     module=FSM-r3
#     # name of the build target (fcmd, fspc, fsm3_octeon2, fsm4_axm or fsm4_k2)
#     moduleTarget=fsm3_octeon2
#     # branch / location name
#     branch=trunk
#     # production label (optional)
#     productionLabel=PS_LFS_OS_$(date +%Y)_$(date +%m)_9999
#     mkdir workspace
#     cd workspace
#     build setup
#     build newlocations ${branch}
#     build adddir src-project
#     for src in $(build -C src-project src-list_${product}_${module}) ; do
#     build adddir ${src}
#     done
#     /ps/lfs/ci/bin/sortBuildsFromDependencies ${moduleTarget} makefile ${productionLabel} > Makefile
#     buildTarget=$(build -C src-project final-build-target_${product}_${module})
#     make ${buildTarget}
#     </pre>
# 
#  naming for the sub build jobs:
#  - LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
#  - LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_k2
#  - LFS_CI_-_trunk_-_Build_-_FSM-r3_-_fsm3_octeon2
#  - LFS_CI_-_trunk_-_Build_-_FSM-r3_-_qemu_64
#  - LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
#  - LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fspc
#  - LFS_CI_-_trunk_-_Build_-_FSM-r2_-_qemu
#  - LFS_CI_-_LRC_-_Build_-_LRC_-_qemu_64
#  - LFS_CI_-_LRC_-_Build_-_LRC_-_lcpa
#
# This build functions are also apply to LFS, UBOOT, LTK, UBOOT_FSMR4, ...
#

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_build}           ]] && source ${LFS_CI_ROOT}/lib/build.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ci_job_build()
#  @brief   usecase job ci build
#  @details the use case job ci build makes a clean build
#  @param   <none>
#  @return  <none>
ci_job_build() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD JOB_NAME BUILD_NUMBER

    info "building targets..."
    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}"

    # for the metrics database, we are installing a own exit handler to record the end of this job
    exit_add _recordBuildEndEvent

    execute rm -rf ${WORKSPACE}/revisions.txt
    createWorkspace

    # release label is stored in the artifacts of fsmci of the build job
    # TODO: demx2fk3 2014-07-15 fix me - wrong function
    copyArtifactsToWorkspace "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "fsmci"
    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    info "subTaskName is ${subTaskName}"
    case ${subTaskName} in
        *FSMDDALpdf*) _build_fsmddal_pdf ;;
        *)            buildLfs           ;;
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
    requiredParameters JOB_NAME BUILD_NUMBER LFS_CI_ROOT 

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName

    debug "BUILD CAUSE by SCM trigger is: ${BUILD_CAUSE_SCMTRIGGER}"
    if [[ ${BUILD_CAUSE_SCMTRIGGER} ]] ; then
        copyChangelogToWorkspace ${JOB_NAME} ${BUILD_NUMBER}
        local linesOfChangelog=$(wc -l ${WORKSPACE}/changelog.xml | cut -d" " -f 1)
        if [[ ${linesOfChangelog} = 1 ]] ; then
            WARNING "build was triggered by SCM change, but changelog is empty"
            setBuildResultUnstable
            exit 0
        fi
    fi

    info "workspace is ${workspace}"

    local jobDirectory=$(getBuildDirectoryOnMaster)
    local lastSuccessfulJobDirectory=$(getBuildDirectoryOnMaster ${JOB_NAME} lastSuccessfulBuild)
    local oldLabel=$(runOnMaster "test -d ${lastSuccessfulJobDirectory} && cat ${lastSuccessfulJobDirectory}/label 2>/dev/null")
    info "old label ${oldLabel} from ${lastSuccessfulJobDirectory} on master"

    if [[ -z ${oldLabel} ]] ; then
        oldLabel="invalid_string_which_will_not_match_do_regex"
    fi

    local branch=$(getBranchName)
    mustHaveBranchName

    local regex=$(getConfig LFS_PROD_branch_to_tag_regex)
    mustHaveValue "${regex}" "branch to tag regex map"

    info "using regex ${regex} for branch ${branch}"

    local label=$(${LFS_CI_ROOT}/bin/getNewTagName -o "${oldLabel}" -r "${regex}" )
    mustHaveValue "${label}" "next release label name"

    info "new version is ${label}"
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    debug "writing new label file in workspace ${workspace}"
    execute mkdir -p ${workspace}/bld/bld-fsmci-summary
    echo ${label}    > ${workspace}/bld/bld-fsmci-summary/label
    echo ${oldLabel} > ${workspace}/bld/bld-fsmci-summary/oldLabel

    debug "writing new label file in ${jobDirectory}/label"
    executeOnMaster "echo ${label} > ${jobDirectory}/label"

    info "upload results to artifakts share."
    createArtifactArchive

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    databaseEventBuildStarted
    databaseAddNewCommits

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
    mustHaveValue ${label} "label name"

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
    execute make -C ${workspace}/src-fsmpsl/src/fsmddal.d/ LABEL=${label}

    # fixme
    local destinationDir=${workspace}/bld/bld-fsmddal-doc/results/doc/
    execute mkdir -p ${destinationDir}
    execute cp ${workspace}/src-fsmpsl/src/fsmddal.d/FSMDDAL.pdf ${destinationDir}
    execute rm -rf ${workspace}/bld/bld-fsmifdd-defcfg

    return
}

_recordBuildEndEvent() {
    local rc=${1}
    if [[ ${rc} -gt 0 ]] ; then
        databaseEventBuildFailed
    else
        databaseEventBuildFinished
    fi
    return
}


## @fn      preCheckoutPatchWorkspace()
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

usecase_LFS_BUILD_POSTACTION() {
    local workspace=$(getWorkspaceName)

    local label=$(getNextCiLabelName)
    mustHaveValue "${label}" "label"

    databaseEventBuildFinished

    return
}
