#!/bin/bash
## @file      build.sh
#  @brief     common function for the usecaes build
#  @details   the usecase build is doing (simplified) the following things:
#             ... example code from CI INFO page ...

LFS_CI_SOURCE_build='$Id$'

[[ -z ${LFS_CI_SOURCE_config}   ]] && source ${LFS_CI_ROOT}/lib/config.sh
[[ -z ${LFS_CI_SOURCE_logging}  ]] && source ${LFS_CI_ROOT}/lib/logging.sh
[[ -z ${LFS_CI_SOURCE_commands} ]] && source ${LFS_CI_ROOT}/lib/commands.sh

## @fn      buildLfs()
#  @brief   make the build
#  @details make the real build. The required build targets / configs will be determinates by
#           sortbuildsfromdependencies. This creates a list with subsystems - configs in the
#           correct order. After this, it calls the build script and executes the build.
#  @todo    replace the sortbuildsfromdependencies with the new implemtation,
#           introduce the new syntax for sortbuildsfromdependencies.
#  @param   <none>
#  @return  <none>
buildLfs() {
    local cfgFile=$(createTempFile)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local target=$(getTargetBoardName)
    mustHaveTargetBoardName

    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}" "subTaskName"
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
        #elif [[ ${name} =~ pkgpool_oldboost ]] ; then
        #    echo "ln -sf /build/home/SC_LFS/pkgpool/${tag} bld/${name}"                    >> ${script}
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

        [[ -d ${component}      ]] || continue
        [[ -d ${component}/.svn ]] || continue
        local revision=$(getSvnLastChangedRevision ${component})
        local url=$(getSvnUrl ${component})
        local componentName=$(sed "s:${workspace}/::" <<< ${component})

        url=$(normalizeSvnUrl ${url})

        debug "using for ${componentName} from ${url} with ${revision}"

        mustHaveValue "${revision}" "svn last changed revision of ${component}"
        mustHaveValue "${url}" "svn url of ${component}"

        printf "%s %s %d\n" ${componentName} ${url} ${revision} >> ${revisionsFile}

    done

    debug "revision file:"
    rawDebug ${revisionsFile}

    return
}
