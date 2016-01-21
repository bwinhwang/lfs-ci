#!/bin/bash
# @file  uc_admin_create_patch_release.sh
# @brief start a patch release

[[ -z ${LFS_CI_SOURCE_artifacts}   ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_fingerprint} ]] && source ${LFS_CI_ROOT}/lib/fingerprint.sh

## @fn      usecase_ADMIN_CREATE_PATCH_RELEASE()
#  @brief   
#  @param   <none>
#  @return  <none>
usecase_ADMIN_CREATE_PATCH_RELEASE() {

    # product name must be set to retrieve the build share
    # The name of the current job is a Admin-Job, not a LFS_CI_-_<branch>... Job!
    # For getConfig / getProductName, we are faking the productName
    export LFS_CI_GLOBAL_PRODUCT_NAME=LFS

    requiredParameters BASE_BUILD IMPORTANT_NOTE BUILD_USER_ID BUILD_USER

    info BASE_BUILD=${BASE_BUILD}
    info FSMR2_PATCH_BUILD=${FSMR2_PATCH_BUILD}
    info FSMR3_PATCH_BUILD=${FSMR3_PATCH_BUILD}
    info FSMR4_PATCH_BUILD=${FSMR4_PATCH_BUILD}
    info IMPORTANT_NOTE=${IMPORTANT_NOTE}
    info BUILD_USER_ID=${BUILD_USER_ID}
    info BUILD_USER=${BUILD_USER}

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${BASE_BUILD} triggered by ${BUILD_USER}"

    # perform several checks
    mustHaveAllBuilds
    mustDifferFromBaseBuild
    mustHaveAllBuildsOfSameBranch
    mustHaveOneEmptyPatchBuild
    mustHaveMinimumOnePatchBuild
    mustHaveNoNestedPatchBuild
    mustBeUnreleasedBaseBuild
    mustHaveFinishedAllPackageJobs

    # create info files explaining that this build is a "patched" one
    markBaseBuildAsPatched

    # copy patch builds into base build
    copyPatchBuildsIntoBaseBuild

    return
}

## @fn      mustHaveAllBuilds()
#  @brief   checks, if directories exist on build share for BASE_BUILD and all given patch builds
#  @param   environment variables (BASE_BUILD, FSMR2_PATCH_BUILD, FSMR3_PATCH_BUILD and FSMR4_PATCH_BUILD)
#  @return  0, if BASE_BUILD and each of the patch builds are found on the share
mustHaveAllBuilds() {
    local releasesPath=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)
    mustHaveValue "${releasesPath}" "share real location"

    for varBuild in BASE_BUILD FSMR2_PATCH_BUILD FSMR3_PATCH_BUILD FSMR4_PATCH_BUILD
    do
        local build=${!varBuild}
        # skip empty build vars
        [[ -z ${build} ]] && continue
        info "checking for ${varBuild} (value: ${build}) on CI_LFS share..."
        mustExistDirectory "${releasesPath}/${build}"
    done

    return 0
}

## @fn      mustDifferFromBaseBuild()
#  @brief   checks, if all given patch builds are different from the base build
#  @param   environment variables (BASE_BUILD, FSMR2_PATCH_BUILD, FSMR3_PATCH_BUILD and FSMR4_PATCH_BUILD)
#  @return  0, if each of the patch builds is different from BASE_BUILD
mustDifferFromBaseBuild() {
    requiredParameters BASE_BUILD

    for varBuild in FSMR2_PATCH_BUILD FSMR3_PATCH_BUILD FSMR4_PATCH_BUILD
    do
        local build=${!varBuild}
        if [[ ${build} == ${BASE_BUILD} ]] ; then
            fatal ${varBuild} refers to same build as BASE_BUILD
        fi
    done

    return 0
}

## @fn      mustHaveAllBuildsOfSameBranch()
#  @brief   all given release labels must be from same LFS branch
#  @param   environment variables (BASE_BUILD, FSMR2_PATCH_BUILD, FSMR3_PATCH_BUILD and FSMR4_PATCH_BUILD)
#  @return  <none>
mustHaveAllBuildsOfSameBranch() {
    info mustHaveAllBuildsOfSameBranch: checking that patch releases are from same branch as base release ....
    requiredParameters BASE_BUILD

    local baseBranchName=$(getBranchNameFromBuildName ${BASE_BUILD})
    mustHaveValue "${baseBranchName}" "baseBranchName"
    info base build ${BASE_BUILD} has branch name ${baseBranchName}

    for varBuild in FSMR2_PATCH_BUILD FSMR3_PATCH_BUILD FSMR4_PATCH_BUILD
    do
        local build=${!varBuild}
        [[ -z ${build} ]] && continue
        local relBranchName=$(getBranchNameFromBuildName ${build})
        mustHaveValue "${relBranchName}" "relBranchName"
        info patch build ${build} has branch name ${relBranchName}
        if [[ ${relBranchName} != ${baseBranchName} ]] ; then
           fatal ${build} is not from same branch as base release ${BASE_BUILD}
        fi
    done

    return
}

## @fn      mustHaveOneEmptyPatchBuild()
#  @brief   At least one build must be the same as the base build. 
#  @param   environment variables (FSMR2_PATCH_BUILD, FSMR3_PATCH_BUILD and/or FSMR4_PATCH_BUILD)
#  @return  <none>
mustHaveOneEmptyPatchBuild() {
    if [[ -z ${FSMR2_PATCH_BUILD} || -z ${FSMR3_PATCH_BUILD} || -z ${FSMR4_PATCH_BUILD} ]] ; then
        return
    fi
    fatal "At least one patch build must be empty (i.e. using the base build) !!"
}

## @fn      mustHaveMinimumOnePatchBuild()
#  @brief   At least one patch build must be given.
#  @param   environment variables (FSMR2_PATCH_BUILD, FSMR3_PATCH_BUILD and/or FSMR4_PATCH_BUILD)
#  @return  <none>
mustHaveMinimumOnePatchBuild() {
    if [[ -z ${FSMR2_PATCH_BUILD} && -z ${FSMR3_PATCH_BUILD} && -z ${FSMR4_PATCH_BUILD} ]] ; then
        fatal "At least one patch build must be given !!"
    fi

    return
}

## @fn      mustHaveNoNestedPatchBuild()
#  @brief   A release is not allowed to make usage of an already patched build. So os/doc/patched_build.xml must not exist
#  @param   environment variables (BASE_BUILD, FSMR2_PATCH_BUILD, FSMR3_PATCH_BUILD and FSMR4_PATCH_BUILD)
#  @return  <none>
mustHaveNoNestedPatchBuild() {
    info mustHaveNoNestedPatchBuild: checking that patch releases are not patched builds
    requiredParameters BASE_BUILD

    local releaseShareRootPath=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)
    info releaseShareRootPath=${releaseShareRootPath}
    mustHaveValue "${releaseShareRootPath}" "releaseShareRootPath"

    for varBuild in BASE_BUILD FSMR2_PATCH_BUILD FSMR3_PATCH_BUILD FSMR4_PATCH_BUILD
    do
        local build=${!varBuild}
        [[ -z ${build} ]] && continue
        info checking that build ${build} is not patched already....
        mustExistDirectory ${releaseShareRootPath}/${build}/os/doc

        # if this file exists it is an already patched version
        mustNotExistFile ${releaseShareRootPath}/${build}/os/doc/patched_build.xml
    done

    return
}

## @fn      mustBeUnreleasedBaseBuild()
#  @brief   check if BASE_BUILD has not been released yet
#  @param   environment variables (BASE_BUILD)
#  @return  0, if BASE_BUILD has not yet been released
mustBeUnreleasedBaseBuild() {
    local osReleaseLabelName=$(sed "s/_LFS_OS_/_LFS_REL_/" <<< ${BASE_BUILD} )
    local releasesPath=$(getConfig LFS_CI_UC_package_copy_to_share_name)/Release

    if [[ -L ${releasesPath}/${osReleaseLabelName} ]] ; then
        fatal "BASE_BUILD=${BASE_BUILD} has already been released!"
    fi

    return 0
}

## @fn      mustHaveFinishedAllPackageJobs()
#  @brief   guarantee that package job of all affected builds has finished already 
#  @param   environment variables (BASE_BUILD FSMR2_PATCH_BUILD FSMR3_PATCH_BUILD FSMR4_PATCH_BUILD) 
#  @return  0, if all package jobs are finished
mustHaveFinishedAllPackageJobs() {
    requiredParameters BASE_BUILD

    for build in BASE_BUILD FSMR2_PATCH_BUILD FSMR3_PATCH_BUILD FSMR4_PATCH_BUILD
    do
        [[ -z ${!build} ]] && continue

        info "mustHaveFinishedAllPackageJobs: processing ${build} (${!build})"
        if ! (getPackageBuildNumberFromFingerprint ${!build}) ; then
            fatal "package job for ${build} (${!build}) is not finished"
        fi
    done
    return
}

## @fn     markBaseBuildAsPatched()
#  @brief   
#  @param   environment variables (BASE_BUILD, BUILD_USER, IMPORTANT_NOTE)
#  @return  <none>
markBaseBuildAsPatched() {
    requiredParameters BASE_BUILD BUILD_USER IMPORTANT_NOTE

    info mark base build as patched ...

    local releaseShareRootPath=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)
    mustHaveValue "${releaseShareRootPath}" "releaseShareRootPath"

    patchXml=${releaseShareRootPath}/${BASE_BUILD}/os/doc/patched_build.xml
    info generating ${patchXml} ...

    cat >${patchXml} <<EOF
<?xml version="1.0"?>
<patched_build>
   <triggeredBy user="${BUILD_USER}"></triggeredBy>
   <build type="base">${BASE_BUILD}</build>
EOF

   [[ ${FSMR2_PATCH_BUILD} ]] && echo "   <build type=\"FSM-r2\">${FSMR2_PATCH_BUILD}</build>" >> ${patchXml}
   [[ ${FSMR3_PATCH_BUILD} ]] && echo "   <build type=\"FSM-r3\">${FSMR3_PATCH_BUILD}</build>" >> ${patchXml}
   [[ ${FSMR4_PATCH_BUILD} ]] && echo "   <build type=\"FSM-r4\">${FSMR4_PATCH_BUILD}</build>" >> ${patchXml}

    cat >>${patchXml} <<EOF
   <importantNote>${IMPORTANT_NOTE}</importantNote>
</patched_build>
EOF
    rawDebug ${patchXml}

    info ${baseBuildName} marked as patched.

    return
}

## @fn     copyPatchBuildsIntoBaseBuild()
#  @brief  copies all patch release relevant parts to base release.
#  @warning common dirs per target is only configured one. (eg. k2 and axm common dirs only connfigured for k2)
#  @brief   
#  @param   environment variables (BASE_BUILD, FSMR2_PATCH_BUILD, FSMR3_PATCH_BUILD, FSMR4_PATCH_BUILD)
#  @return  <none>
copyPatchBuildsIntoBaseBuild() {
    requiredParameters BASE_BUILD

    info copying patch releases into base build ....

    local fsmr2BuildName=${FSMR2_PATCH_BUILD}
    local fsmr3BuildName=${FSMR3_PATCH_BUILD}
    local fsmr4BuildName=${FSMR4_PATCH_BUILD}

    local releaseShareRootPath=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)
    debug releaseShareRootPath=${releaseShareRootPath}
    mustHaveValue "${releaseShareRootPath}" "releaseShareRootPath"

    # get all available hw platforms (fsmr4, fsmr3,...)
    local hwPlatforms=$(getConfig LFS_hw_platforms)
    debug hwPlatforms=${hwPlatforms}
    mustHaveValue "${hwPlatforms}" "hwPlatforms"

    for  hwPlatform in ${hwPlatforms}
    do
        debug hwPlatform=${hwPlatform}
        local currPatchBuild="${hwPlatform}BuildName"
        debug currPatchBuild=${!currPatchBuild}
        [[ -z ${!currPatchBuild} ]] && continue

        #copy patch changelog to base build
        local packageJobName=$(getPackageJobNameFromFingerprint ${!currPatchBuild})
        local packageBuildNumber=$(getPackageBuildNumberFromFingerprint ${!currPatchBuild})

        local baseDocDir=${releaseShareRootPath}/${BASE_BUILD}/os/doc
        debug baseDocDir=${baseDocDir}
        local baseDocPatchDir=${baseDocDir}/patched_release
        debug baseDocPatchDir=${baseDocPatchDir}
        [[ ! -d ${baseDocPatchDir} ]] && mkdir ${baseDocPatchDir}

        info copy ${hwPlatform}_changelog.xml to base build ${BASE_BUILD} ...
        copyChangelogToWorkspace ${packageJobName} ${packageBuildNumber}
        execute cp ${WORKSPACE}/changelog.xml ${baseDocPatchDir}/${hwPlatform}_changelog.xml

        info copy ${hwPlatform}_scripts to base build ${BASE_BUILD} ...
        execute cp -rf ${releaseShareRootPath}/${!currPatchBuild}/os/doc/scripts ${baseDocPatchDir}/${hwPlatform}_scripts

        local osDirs=$(getConfig LFS_release_os_dirs -t "hw_platform:${hwPlatform}")
        mustHaveValue "${osDirs}" "osDirs"
        debug osDirs = ${osDirs}
        for  osDir in ${osDirs}
        do
            debug osDir=${osDir}
            local osSubdir=$(getConfig LFS_release_os_subdir -t "hw_platform:${hwPlatform}" -t "os_dir:${osDir}")
            mustHaveValue "${osSubdir}" "osSubdir"
            debug osSubdir=${osSubdir}

            # remove last dir of osSubdir to get dest_dir
            local dest_osSubDir=${osSubdir%/*}
            debug dest_osSubDir=${dest_osSubDir}

            info now executing rsync -avP --delete --stats ${releaseShareRootPath}/${!currPatchBuild}/${osSubdir}    ${releaseShareRootPath}/${BASE_BUILD}/${dest_osSubDir}/
            execute rsync -avP --delete --stats ${releaseShareRootPath}/${!currPatchBuild}/${osSubdir}    ${releaseShareRootPath}/${BASE_BUILD}/${dest_osSubDir}/

        done
    done

    info patch releases copied into base release.

    return
}

