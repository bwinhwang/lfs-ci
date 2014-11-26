#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

## @fn      ci_job_build()
#  @brief   usecase job ci build
#  @details the use case job ci build makes a clean build
#  @param   <none>
#  @return  <none>
ci_job_build() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD JOB_NAME BUILD_NUMBER

    info "creating the workspace..."
    createWorkspace

    info "building targets..."
    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}"

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

    local subTaskName=$(getSubTaskNameFromJobName)
    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "productName"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label}

    execute cd ${workspace}
    storeExternalComponentBaselines
    storeRevisions      ${target}
    createRebuildScript ${target}

    info "creating temporary makefile"
    execute -n ${LFS_CI_ROOT}/bin/sortBuildsFromDependencies ${target} makefile ${label} > ${cfgFile}
    rawDebug ${cfgFile}

    local makeTarget=$(build -C src-project final-build-target_${productName}_${subTaskName})
    mustHaveValue "${makeTarget}" "make target name from src-project/Buildfile"
    info "executing all targets in parallel with ${makeTarget} and label=${label}"
    execute make -f ${cfgFile} ${makeTarget} JOBS=32

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

## @fn      storeExternalComponentBaselines()
#  @brief   store externals components baseline into a artifacts file
#  @details The information is used during the releasing later for tagging.
#           Externals components can be configured in config LFS_CI_UC_build_externalsComponents.
#           Externals components are baselines like sdk{1,2,3,} or pkgpool.  
#  @param   <none>
#  @return  <none>
storeExternalComponentBaselines() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local externalComponentFile=${workspace}/bld/bld-externalComponents-summary/externalComponents

    info "store used baselines (bld) information"

    execute mkdir -p ${workspace}/bld/bld-externalComponents-summary/
    execute rm -f ${externalComponentFile}

    # storing sdk labels for later use in a artifact file.
    for component in $(getConfig LFS_CI_UC_build_externalsComponents) ; do
        [[ -e ${workspace}/bld/${component} ]] || continue
        local baselineLink=$(readlink ${workspace}/bld/${component})
        local baseline=$(basename ${baselineLink})

        # TODO: demx2fk3 2014-09-08 if you are change the format, please change also createRebuildScript 
        trace "component ${component} exists with link to ${baselineLink} and ${baseline}"
        printf "%s <> = %s\n" "${component}" "${baseline:-undef}" >> ${externalComponentFile}
    done

    rawDebug ${externalComponentFile}

    return
}

## @fn      createRebuildScript()
#  @brief   create the rebuild script workdir.sh for a specific target
#  @param   {targetName}    name of the target
#  @return  <none>
createRebuildScript() {
    requiredParameters JOB_NAME BUILD_NUMBER

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    info "adding svn commands to rebuilding script"

    # TODO: demx2fk3 2014-11-06 why did I removed the -?
    # local targetName=$(sed "s/-//g" <<< ${1})
    local targetName=$1
    mustHaveValue "${targetName}" "target name"

    local script=${workspace}/bld/bld-externalComponents-${targetName}/workdir_${targetName}.sh
    mustExistFile ${workspace}/bld/bld-externalComponents-summary/externalComponents
    mustExistFile ${workspace}/bld/bld-externalComponents-${targetName}/usedRevisions.txt

    echo "#!/bin/bash"                                                                     >> ${script}
    echo "# script was automatically created by jenkins job ${JOB_NAME} / ${BUILD_NUMBER}" >> ${script}
    echo "# for details ask PS LFS SCM"                                                    >> ${script}
    echo "# This script is for ${targetName}"                                              >> ${script}
    echo                                                                                   >> ${script}
    echo "set -o errexit"                                                                  >> ${script}
    echo "set -o allexport"                                                                >> ${script}
    echo "set -o nounset"                                                                  >> ${script}
    echo "mkdir workdir-${targetName}"                                                     >> ${script}
    echo "cd workdir-${targetName}"                                                        >> ${script}
    echo "mkdir -p bld bldtools locations .build_workdir"                                  >> ${script}
   
    # reading the external components file and create the lines for linking them 
    # into the workspace
    local tag=
    local name=
    local junk1=
    local junk2=
    while read name junk1 junk2 tag ; do

        # TODO: demx2fk3 2014-09-08 make the pathnames configurable
        if [[ ${name} =~ sdk ]] ; then
            echo "ln -sf /build/home/SC_LFS/sdk/tags/${tag} bld/${name}"                   >> ${script}
        elif [[ ${name} =~ pkgpool ]] ; then
            echo "ln -sf /build/home/SC_LFS/pkgpool/${tag} bld/${name}"                    >> ${script}
        elif [[ ${name} =~ bld- ]] ; then
            echo "ln -sf /build/home/SC_LFS/releases/bld/${name}/${tag} bld/${name}"       >> ${script}
        else
            fatal "component in bld ${name} not supported in creation of workdir.sh"
        fi
    done < ${workspace}/bld/bld-externalComponents-summary/externalComponents

    # create the lines for the svn co commands...
    while read src url rev ; do
        echo "svn checkout -r ${rev} ${url} ${src}"                                        >> ${script}
    done < ${workspace}/bld/bld-externalComponents-${targetName}/usedRevisions.txt

    echo "echo done"                                                                       >> ${script}
    echo "exit 0"                                                                          >> ${script} 

    debug "workdir.sh for ${targetNme} was created successfully"
    rawDebug ${script}

    return 
}

## @fn      storeRevisions()
#  @brief   store all the revisions of the used src-directories (incl. bldtools and locations)
#  @details this information will be used and is required later for tagging the sources
#           the file will be stored in the artifacts and is so accessable for following jobs
#  @param   <none>
#  @return  <none>
storeRevisions() {
    # TODO: demx2fk3 2014-11-06 why did I removed the -?
    # local targetName=$(sed "s/-//g" <<< ${1})
    local targetName=$1
    mustHaveValue "${targetName}" "target name"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local revisionsFile=${workspace}/bld/bld-externalComponents-${targetName}/usedRevisions.txt

    info "store svn revision information"

    execute mkdir -p ${workspace}/bld/bld-externalComponents-${targetName}/
    execute rm -f ${revisionsFile}

    for component in ${workspace}/{src-,bldtools/bld-buildtools-common,locations/}* ; do

        [[ -d ${component} ]] || continue
        local revision=$(getSvnLastChangedRevision ${component})
        local url=$(getSvnUrl ${component})
        local componentName=$(sed "s:${workspace}/::" <<< ${component})

        url=$(normalizeSvnUrl ${url})

        debug "using for ${componentName} from ${url} with ${revision}"

        mustHaveValue "${revision}" "svn last changed revision of ${component}"
        mustHaveValue "${url}" "svn url of ${component}"

        printf "%s %s %d\n" ${componentName} ${url} ${revision} >> ${revisionsFile}

    done

    return
}
