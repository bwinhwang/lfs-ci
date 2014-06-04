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

    local location=$(getLocationName)
    local branch=${locationToSubversionMap["${location}"]}

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
    local workspace=${ciBuildShare}/${location}/build_${packageBuildNumber}
    mustExistDirectory  ${workspace}

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
        create_release_tag)
            createReleaseTag ${buildJobName} ${buildBuildNumber}
        ;;
        create_source_tag) 
            createTagOnSourceRepository ${buildJobName} ${buildBuildNumber}
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
#  @details «full description»
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
    local jobName=$1
    local buildNumber=$2

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace
    info "workspace is ${workspace}"

    # get os label
    # no mustHaveNextLabelName, because it's already calculated
    local osLabelName=$(getNextReleaseLabel)
    mustHaveValue "${osLabelName}" "no os label name"

    # get artifacts
    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"
    revisionFile=${workspace}/bld//bld-externalComponents-summary/usedRevisions.txt
    mustExistFile ${revisionFile}
    rawDebug ${revisionFile}

    # check for branch
    local svnUrl=$(getConfig lfsSourceRepos)/os
    local branch=demx2fk3_pre_${osLabelName}

    svnUrl=$(normalizeSvnUrl ${svnUrl})
    mustHaveValue "${svnUrl}" "svnUrl"

    info "using lfs os ${osLabelName}"
    info "using repos ${svnUrl}/branches/${branch}"
    info "creating new tag ${svnUrl}/tags/${osLabelName}"

    if existsInSubversion ${svnUrl}/tags ${osLabelName} ; then
        error "tag ${osLabelName} already exists"
        exit 1
    fi

    if existsInSubversion ${svnUrl}/branches ${branch} ; then
        info "removing branch ${branch}"
        svnRemove -m removing_branch_for_production ${svnUrl}/branches/${branch} 
    fi

    info "creating branch ${branch}"
    svnMkdir -m creating_new_branch_${branch} ${svnUrl}/branches/${branch}

    for componentUrl in $(cat ${revisionFile}) ; do
        local url=$(cut -d@ -f1 <<< ${componentUrl})
        local rev=$(cut -d@ -f2 <<< ${componentUrl})
        local src=$(basename ${url})
        mustHaveValue "${url}" "svn url"
        mustHaveValue "${rev}" "svn revision"

        local normalizedUrl=$(normalizeSvnUrl ${url})

        info "copy ${src} to ${branch}"
        svnCopy -r ${rev} -m branching_src_${src}_to_${branch} \
            ${normalizedUrl}                             \
            ${svnUrl}/branches/${branch}
    done

    # check for the branch
    info "svn repos url is ${svnUrl}/branches/${branch}"
    shouldNotExistsInSubversion ${svnUrl}/tags/ "${osReleaseLabelName}"

    echo svnCopy -m create_new_tag_${osLabelName} \
        ${svnUrl}/branches/${branch}             \
        ${svnUrl}/tags/${osLabelName}

    info "branch ${branch} no longer required, removing branch"
    svnRemove -m removing_branch_for_production ${svnUrl}/branches/${branch} 

    info "tagging done"

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
    info "workspace is ${workspace}"

    # get os label
    # no mustHaveNextLabelName, because it's already calculated
    local osLabelName=$(getNextReleaseLabel)
    local osReleaseLabelName=$(sed "s/_LFS_OS_/_LFS_REL_/" <<< ${osLabelName} )
    mustHaveValue "${osLabelName}" "no os label name"

    # check for branch
    local svnUrl=$(getConfig lfsRelDeliveryRepos)
    local branch=$(getBranchName)
    mustHaveBranchName

    # get sdk label
    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"
    commonentsFile=${workspace}/bld//bld-externalComponents-summary/externalComponents   
    mustExistFile ${commonentsFile}

    local sdk2=$(getConfig sdk2 ${commonentsFile})
    local sdk3=$(getConfig sdk3 ${commonentsFile})

    info "using sdk2 ${sdk2}"
    info "using sdk3 ${sdk3}"
    info "using lfs os ${osLabelName}"
    info "using lfs rel ${osReleaseLabelName}"

    # check for the branch
    info "svn repos url is ${svnUrl}/branches/${branch}"
    shouldNotExistsInSubversion ${svnUrl}/tags/ "${osReleaseLabelName}"

    if ! existsInSubversion ${svnUrl}/branches ${branch} ; then
        svnMkdir -m \"creating branch for ${branch}\" ${svnUrl}/branches/${branch} 
    fi

    # update svn:externals
    local svnExternalsFile=$(createTempFile)
    echo "^/os/tags/${osLabelName} os " >> ${svnExternalsFile}

    if [[ ${sdk3} ]] ; then 
        echo "^/sdk/tags/{sdk3} sdk3" >> ${svnExternalsFile}
    fi

    if [[ ${sdk2} ]] ; then 
        echo "^/sdk/tags/{sdk2} sdk2" >> ${svnExternalsFile}
    fi

    # commit
    info "updating svn:externals"
    svnCheckout --ignore-externals ${svnUrl}/branches/${branch} ${workspace}/svn

    cd ${workspace}/svn
    svnPropSet svn:externals -F ${svnExternalsFile} .
    svnCommit -m updating_svn:externals_for_${osReleaseLabelName} .

    # make a tag
    info "create tag ${osReleaseLabelName}"
    svnCopy -m create_new_tag ${svnUrl}/branches/${branch} ${svnUrl}/tags/${osReleaseLabelName}

    info "tag created..."

    return
}

