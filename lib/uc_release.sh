#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh
source ${LFS_CI_ROOT}/lib/subversion.sh

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @param   <none>
#  @return  <none>
ci_job_release() {

    # requiredParameters TESTED_BUILD_JOBNAME TESTED_BUILD_NUMBER
    requiredParameters JOB_NAME BUILD_NUMBER

    local serverPath=$(getConfig jenkinsMasterServerPath)
    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    local branch=$(getBranchName)
    mustHaveBranchName

    local upstreamsFile=$(createTempFile)

    info "promoted build is ${TESTED_BUILD_JOBNAME} / ${TESTED_BUILD_NUMBER}"

    # find the related jobs of the build
    runOnMaster ${LFS_CI_ROOT}/bin/getUpStreamProject \
                    -j ${TESTED_BUILD_JOBNAME}        \
                    -b ${TESTED_BUILD_NUMBER}         \
                    -h ${serverPath} > ${upstreamsFile}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    if ! grep -q Package ${upstreamsFile} ; then
        error "cannot find upstream Package job"
        exit 1
    fi
    if ! grep -q Build   ${upstreamsFile} ; then
        error "cannot find upstream Build build"
        exit 1
    fi

    mustHaveNextLabelName
    local releaseLabel=$(getNextReleaseLabel)
    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local packageJobName=$(    grep Package ${upstreamsFile} | cut -d: -f1)
    local buildBuildNumber=$(  grep Build   ${upstreamsFile} | cut -d: -f2)
    local buildJobName=$(      grep Build   ${upstreamsFile} | cut -d: -f1)
    mustHaveValue ${packageJobName}
    mustHaveValue ${packageBuildNumber}
    mustHaveValue ${buildJobName}
    mustHaveValue ${buildBuildNumber}
    mustHaveValue ${releaseLabel}

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${releaseLabel}"

    info "found package job: ${packageJobName} / ${packageBuildNumber}"
    info "found build   job: ${buildJobName} / ${buildBuildNumber}"
    
    local ciBuildShare=$(getConfig lfsCiBuildsShare)
    local workspace=${ciBuildShare}/${branch}/build_${packageBuildNumber}
    if [[ ! -d ${workspace} ]] ; then
        error "can not find workspace of package job on build share (${workspace})"
        exit 1
    fi

    debug "found results of package job on share: ${workspace}"

    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    info "subJob is ${subJob}"
    case ${subJob} in
        upload_to_subversion)
            # from subversion.sh
            uploadToSubversion "${workspace}" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"
        ;;
        build_results_to_share)
            extractArtifactsOnReleaseShare "${buildJobName}" "${buildBuildNumber}"
        ;;
        build_results_to_share_on_site)
            copyToReleaseShareOnSite "${buildJobName}" "${buildBuildNumber}"
        ;;
        create_releasenote_textfile)
            createReleaseNoteTextFile ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER}
        ;;
        summary)
            # no op
        ;;
        *)
            error "subJob not known (${subJob})"
            exit 1
        ;;
    esac

    return
}

## @fn      extractArtifactsOnReleaseShare( $jobName, $buildNumber )
#  @brief   extract the artifacts of build job on the local workspace and copy the artifacts to the
#           /build share.
#  @details structure on the share is
#           bld-<ss>-<cfg>/<label>/results/...
#  @param   {jobName}      name of the job
#  @param   {buildNumber}  number of the build
#  @return  <none>
extractArtifactsOnReleaseShare() {
    local jobName=$1
    local buildNumber=$2
    local workspace=$(getWorkspaceName)
    local server=$(getConfig jenkinsMasterServerHostName)
    local ciBuildShare=$(getConfig lfsCiBuildsShare)
    mustHaveWorkspaceName

    mustHaveNextLabelName
    local labelName=$(getNextReleaseLabel)
    mustHaveValue "${labelName}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"

    cd ${workspace}/bld/
    for dir in bld-*-* ; do
        [[ -d ${dir} ]] || continue
        basename=$(basename ${dir})

        local destination=${ciBuildShare}/buildresults/${basename}/${labelName}
        info "copy ${basename} to buildresults share ${destination}"

        executeOnMaster mkdir -p ${destination}
        execute rsync -av --exclude=.svn ${workspace}/bld/${basename}/. ${server}:${destination}
    done

    info "clean up workspace"
    execute rm -rf ${workspace}/bld

    return
}

## @fn      copyToReleaseShareOnSite()
#  @brief   copy the released version from the build share to the other sites
#  @details �full description�
#  @todo    more doc
#  @param   <none>
#  @return  <none>
copyToReleaseShareOnSite_copyToSite() {

    requiredParameters SITE_NAME RELEASE_NAME

    local siteName=${SITE_NAME}
    local labelName=${RELEASE_NAME}
    local ciBuildShare=$(getConfig lfsCiBuildsShare)

    for subsystemDirectory in $(find ${ciBuildShare}/buildresults/ -maxdepth 2 -name ${labelName} ) ; do
        [[ -d ${subsystemDirectory} ]] || continue

        local sourceDirectory=${subsystemDirectory}
        info "copy ${sourceDirectory} to ${siteName}"

        # TODO: demx2fk3 2014-05-05 not fully implemented

    done

    return
}

createReleaseNoteTextFile() {
    local jobName=$1
    local buildNumber=$2

    # get the change log file from master
    local buildDirectory=$(getBuildDirectoryOnMaster ${jobName} ${buildNumber})
    local serverName=$(getConfig jenkinsMasterServerHostName)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    execute rsync -ae ssh ${serverName}:${buildDirectory}/changelog.xml ${workspace}

    # TODO: demx2fk3 2014-05-28 annotate with additonal informations

    # convert the changelog xml to a release note
    cd ${workspace}

    echo -e "Hi all,\nThe LFS Release ${releaseLabel} is available in Subversion.\n\n"

    ${LFS_CI_ROOT}/bin/getReleaseNoteContent > releasenote.txt
    mustBeSuccessfull "$?" "getReleaseNoteContent"


    # store release note as artifact
    cat releasenote.txt

    return
}

createReleaseNoteXmlFile() {
    requiredParameters JOB_NAME BUILD_NUMBER        

    # get the change log file from master
    local buildDirectory=$(getBuildDirectoryOnMaster)
    local serverName=$(getConfig jenkinsMasterServerHostName)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    execute rsync -ae ssh ${serverName}:${buildDirectory}/changelog.xml ${workspace}
    
    # convert changelog to release note xml file

    return
}

releaseBuildToWorkFlowTool() {
    requiredParameters JOB_NAME BUILD_NUMBER        
    return
}


createTagOnSourceRepository() {
    requiredParameters JOB_NAME BUILD_NUMBER        
    return
}

## @fn      createReleaseTag()
#  @brief   create the release tag
#  @details the release tag / branch just contains a svn:externals with two externals to sdk and lfs_os tag
#  @param   <none>
#  @return  <none>
createReleaseTag() {
    local jobName=$1
    local buildNumber=$2

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    local osLabelName=$(getNextLabelName)

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"

    find ${workspace}

    commonentsFile=${workspace}/bld//bld-externalComponents-summary/externalComponents   
    mustExistFile ${commonentsFile}
    local sdk=$(getConfig sdk ${commonentsFile})

    # check for branch
#    local svnUrl=$(getConfig lfsRelDeliveryRepos)
#    local svnBranch=...

    # get sdk label


    # get os label
    # update svn:externals
#    svnExternalsFile=$(getTempFile)
#    echo "^os  ${osLabel}"   > ${svnExternalsFile}
#    echo "^sdk ${osLabel}"  >> ${svnExternalsFile}
#
    # commit
#    svnPropEdit svn:externals -m "update svn:externals" -F ${svnExternalsFile} ${workspace}
#
    # make a tag
#    svnCopy 

    return
}

