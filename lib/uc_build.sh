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
[[ -z ${LFS_CI_SOURCE_jenkins}         ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

## @fn      ci_job_build()
#  @brief   usecase job ci build
#  @details the use case job ci build makes a clean build
#  @param   <none>
#  @return  <none>
ci_job_build() {
    usecase_LFS_BUILD_PLATFORM
}

## @fn      usecase_LFS_BUILD_PLATFORM()
#  @brief   run the usecase LFS BUILD PLATFORM
#  @details build the software for a platform / hardware variant
#  @param   <none>
#  @return  <none>
usecase_LFS_BUILD_PLATFORM() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD JOB_NAME BUILD_NUMBER

    info "building targets..."
    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}"
    mustHaveCleanWorkspace

    copyAndExtractBuildArtifactsFromProject "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "fsmci"
    mustHaveNextCiLabelName

    # for the metrics database, we are installing a own exit handler to record the end of this job
    storeEvent subbuild started
    exit_add _recordSubBuildEndEvent

    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    execute rm -rf ${WORKSPACE}/revisions.txt
    createWorkspace

    copyAndExtractBuildArtifactsFromProject "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "fsmci"
    mustHaveNextCiLabelName

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

## @fn      usecase_LFS_BUILD_CREATE_VERSION()
#  @brief   usecase which creates the new build name
#  @details this usecase get the old and new build name from the database
#           by invoking stored procedures on the database.
#  @param   <none>
#  @return  <none>
usecase_LFS_BUILD_CREATE_VERSION() {
    requiredParameters JOB_NAME BUILD_NUMBER LFS_CI_ROOT 
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    info "workspace is ${workspace}"

    productName=$(getProductNameFromJobName)
    labelPrefix=$(getConfig LFS_PROD_label_prefix)
    branch=$(getBranchName)
    mustHaveBranchName

    mustHaveDatabaseCredentials
    local oldBuildName=""
    local buildName=$(_get_new_build_name)
    if [[ ! ${buildName} =~ _0001$ ]]; then
        oldBuildName=$(_get_last_successful_build_name)
        if [[ ${oldBuildName} == ${buildName} ]]; then
            fatal "old and new build name are the same"
        fi
    else
        info "In case of 1'st build there is no old build name"
    fi

    info "new build name is ${buildName}"
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${buildName}"

    debug "writing new build name file in workspace ${workspace}"
    execute mkdir -p ${workspace}/bld/bld-fsmci-summary
    echo ${buildName}    > ${workspace}/bld/bld-fsmci-summary/label
    if [[ ${oldBuildName} ]]; then
        echo ${oldBuildName} > ${workspace}/bld/bld-fsmci-summary/oldLabel
    else
        echo "invalid_string_from_usecase_LFS_BUILD_CREATE_VERSION" > ${workspace}/bld/bld-fsmci-summary/oldLabel
    fi
    
    createFingerprintFile

    # for the metrics database, we are installing a own exit handler to record the end of this job
    eventBuildStarted
    exit_add _recordBuildEndEvent

    info "upload results to artifakts share."
    createArtifactArchive

    databaseAddNewCommits

    return
}

## @fn      ci_job_build_version()
#  @brief   usecase wrapper for usecase_LFS_BUILD_CREATE_VERSION
#  @param   <none>
#  @return  <none>
ci_job_build_version() {
    usecase_LFS_BUILD_CREATE_VERSION
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

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    # lrc | fsm
    local component=$(getConfig LFS_CI_uc_build_create_ddal_pdf_component)
    mustHaveValue "${component}" "component"

    cd ${workspace}
    # TODO: demx2fk3 2015-03-09 FIXME
    if [[ ${component} = lrc ]] ; then
        execute build -C src-ifdd    -L src-ifdd.log defcfg
    else
        execute build -C src-fsmifdd -L src-fsmifdd.log defcfg
    fi

    local tmpDir=$(createTempDirectory)
    execute mkdir -p ${tmpDir}/ddal/
    # remark: this hiere is still fsmifddg!!!
    execute cp -r ${workspace}/bld/bld-fsmifdd-defcfg/results/include ${tmpDir}/ddal/

    # remark: the target is also expected as fsmifdd.tgz
    execute tar -C   ${tmpDir} \
                -czf ${workspace}/src-${component}psl/src/${component}ddal.d/fsmifdd.tgz \
                ddal

    echo ${label} > ${workspace}/src-${component}psl/src/${component}ddal.d/label
    execute make -C ${workspace}/src-${component}psl/src/${component}ddal.d/ LABEL=${label}


    # remark: the result file is FSMDDAL.pdf
    local destinationDir=${workspace}/bld/bld-${component}ddal-doc/results/doc/
    execute mkdir -p ${destinationDir}
    execute cp ${workspace}/src-${component}psl/src/${component}ddal.d/FSMDDAL.pdf ${destinationDir}
    execute rm -rf ${workspace}/bld/bld-fsmifdd-defcfg

    if [[ -e ${workspace}/src-${component}ddal/src/doc/Doxyfile ]] ; then
        cd ${workspace}/
        execute doxygen ${workspace}/src-${component}ddal/src/doc/Doxyfile
        execute mv html ${destinationDir}
    fi


    return
}

## @fn      _recordSubBuildEndEvent()
#  @brief   exit handler for recording the event for the sub build job
#  @param   {rc}    exit code of the programm
#  @return  <none>
_recordSubBuildEndEvent() {
    local rc=${1}
    if [[ ${rc} -gt 0 ]] ; then
        storeEvent subbuild_failed
    else
        storeEvent subbuild_finished
    fi
    return
}

## @fn      _recordBuildEndEvent()
#  @brief   exit handler for recording the event for the build job
#  @param   {rc}    exit code of the programm
#  @return  <none>
_recordBuildEndEvent() {
    local rc=${1}
    if [[ ${rc} -gt 0 ]] ; then
        storeEvent build_failed
    else
        storeEvent build_finished
    fi
    return
}


_get_new_build_name() {
    info "get new build name for ${branch} and product name ${productName} from database"

    # use 2> /dev/null because newer versions of mysql client print a warning
    # to stderr when the password is provided on the commandline.
    local buildName=$(echo "SELECT get_new_build_name('"${branch}"', '"${productName}"', '"${labelPrefix}"')" | \
            mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName} 2> /dev/null)

    if [[ $? != 0 || ${buildName} == NULL || ${buildName} == "" ]]; then
        fatal "did not get a new build name from DB"
    fi

    buildName=${labelPrefix^^}${buildName}

    echo ${buildName}
}

_get_last_successful_build_name() {
    info "get last successful build name for ${branch} and product name ${productName} from database"

    local oldBuildName=$(echo "SELECT get_last_successful_build_name('"${branch}"', '"${productName}"', '"${labelPrefix}"')" | \
            mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName} 2> /dev/null)

    if [[ $? != 0 || ${oldBuildName} == NULL || ${oldBuildName} == "" ]]; then
        fatal "did not get the old build name from DB"
    fi

    info "old build name is ${oldBuildName}"
    echo ${oldBuildName}
}
