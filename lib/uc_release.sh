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
    local product=$(getProductNameFromJobName)
    local branch=${locationToSubversionMap["${product}_${location}"]}

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
    local packageJobName=$(    grep Package ${upstreamsFile} | cut -d: -f1)
    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local buildJobName=$(      grep Build   ${upstreamsFile} | cut -d: -f1)
    local buildBuildNumber=$(  grep Build   ${upstreamsFile} | cut -d: -f2)
    local productName=$(getProductNameFromJobName)
    mustHaveValue ${packageJobName}
    mustHaveValue ${packageBuildNumber}
    mustHaveValue ${buildJobName}
    mustHaveValue ${buildBuildNumber}
    mustHaveValue ${releaseLabel}
    mustHaveValue "${productName}" "product name"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${releaseLabel}"

    info "found package job: ${packageJobName} / ${packageBuildNumber}"
    info "found build   job: ${buildJobName} / ${buildBuildNumber}"
    
    local ciBuildShare=$(getConfig lfsCiBuildsShare)
    local workspace=${ciBuildShare}/${productName}/${location}/build_${packageBuildNumber}
    mustExistDirectory  ${workspace}

    debug "found results of package job on share: ${workspace}"

    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    info "sub task is ${subJob}"
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
            # TODO: demx2fk3 2014-06-05  is this correct?!?!
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

## @fn      createReleaseNoteTextFile()
#  @brief   create a release note in txt format
#  @param   <none>
#  @return  <none>
createReleaseNoteTextFile() {
    local jobName=$1
    local buildNumber=$2


    # TODO: demx2fk3 2014-06-05  is this correct?!?!
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

## @fn      createReleaseNoteXmlFile()
#  @brief   create a release note in xml format
#  @todo    not implemented
#  @param   <none>
#  @return  <none>
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


## @fn      createTagOnSourceRepository( $jobName, $buildNumber )
#  @brief   create a tag(s) on source repository 
#  @details create tags in the source repository (os/tags) and subsystems (subsystems/tags)
#  @param   {jobName}        a job name
#  @param   {buildNumber}    a build number
#  @param   <none>
#  @return  <none>
createTagOnSourceRepository() {
    local jobName=$1
    local buildNumber=$2

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceWithArtefactsFromUpstreamProjects ${jobName} ${buildNumber}

    # get os label
    # no mustHaveNextLabelName, because it's already calculated
    local osLabelName=$(getNextReleaseLabel)
    mustHaveValue "${osLabelName}" "no os label name"


    # get artifacts
    revisionFile=${workspace}/bld//bld-externalComponents-summary/usedRevisions.txt
    cat ${workspace}/bld//bld-externalComponents-*/usedRevisions.txt | sort -u > ${revisionFile}
    rawDebug ${revisionFile}


    # TODO: demx2fk3 2014-06-06 CLEAN UP!!!!
    #
    #       _                                _ 
    #   ___| | ___  __ _ _ __    _   _ _ __ | |
    #  / __| |/ _ \/ _` | '_ \  | | | | '_ \| |
    # | (__| |  __/ (_| | | | | | |_| | |_) |_|
    #  \___|_|\___|\__,_|_| |_|  \__,_| .__/(_)
    #                                 |_|      

    # TODO: demx2fk3 2014-06-06 add check: ensure, that locataions are unque
    mustExistFile ${revisionFile}
    rawDebug ${revisionFile}

    # check for branch
    local svnUrl=$(getConfig lfsSourceRepos)
    local svnUrlOs=${svnUrl}/os
    local branch=pre_${osLabelName}

    svnUrlOs=$(normalizeSvnUrl ${svnUrlOs})
    svnUrl=$(normalizeSvnUrl ${svnUrl})
    mustHaveValue "${svnUrl}" "svnUrl"
    mustHaveValue "${svnUrlOs}" "svnUrlOs"

    info "using lfs os ${osLabelName}"
    info "using repos ${svnUrlOs}/branches/${branch}"
    info "using repos for new tag ${svnUrlOs}/tags/${osLabelName}"
    info "using repos for package ${svnUrl}/subsystems/"

    if existsInSubversion ${svnUrlOs}/tags ${osLabelName} ; then
        error "tag ${osLabelName} already exists"
        exit 1
    fi

    if existsInSubversion ${svnUrlOs}/branches ${branch} ; then
        info "removing branch ${branch}"
        svnRemove -m removing_branch_for_production ${svnUrlOs}/branches/${branch} 
    fi

    info "creating branch ${branch}"
    svnMkdir -m creating_new_branch_${branch} ${svnUrlOs}/branches/${branch}

    while read src url rev ; do
        mustHaveValue "${url}" "svn url"
        mustHaveValue "${rev}" "svn revision"
        mustHaveValue "${src}" "src"

        info "src ${src}"
        info "rev ${rev}"
        info "url ${url}"

        local dirname=

        local normalizedUrl=$(normalizeSvnUrl ${url})

        case ${src} in 
            src-*)
                # TODO continue here
                svnCopy -m tag_for_package_src_${src} ${svnUrlOs}/branches/${branch} \
                    ${svnUrl}/subsystems/${src}/${osLabelName}
            ;;
            *)
                dirname=$(dirname ${src})
                svnMkdir -m mkdir_for_${src} ${svnUrlOs}/branches/${branch}/${dirname}
            ;;
        esac

        info "copy ${src} to ${branch}"
        svnCopy -r ${rev} -m branching_src_${src}_to_${branch} \
            ${normalizedUrl}                                   \
            ${svnUrlOs}/branches/${branch}/${dirname}

    done < ${revisionFile}

    # check for the branch
    info "svn repos url is ${svnUrl}/branches/${branch}"

    svnCopy -m create_new_tag_${osLabelName} \
        ${svnUrl}/os/branches/${branch}             \
        ${svnUrl}/os/tags/${osLabelName}

    info "branch ${branch} no longer required, removing branch"
    svnRemove -m removing_branch_for_production ${svnUrlOs}/branches/${branch} 

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
    mustHaveWorkspaceWithArtefactsFromUpstreamProjects ${jobName} ${buildNumber}

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
        svnMkdir -m creating_branch_for_${branch} ${svnUrl}/branches/${branch} 
    fi

    # update svn:externals
    local svnExternalsFile=$(createTempFile)
    echo "^/os/tags/${osLabelName}/os os " >> ${svnExternalsFile}

    if [[ ${sdk3} ]] ; then 
        echo "/isource/svnroot/BTS_D_SC_LFS/sdk/tags/${sdk3} sdk3" >> ${svnExternalsFile}
    fi

    if [[ ${sdk2} ]] ; then 
        echo "/isource/svnroot/BTS_D_SC_LFS/sdk/tags/${sdk2} sdk2" >> ${svnExternalsFile}
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

    info "tag created."
    return
}

## @fn      mustHaveWorkspaceWithArtefactsFromUpstreamProjects( $jobsName, $buildNumber )
#  @brief   ensures, that a new workspace will be created with artifacts of the upstream project
#  @param   {jobsName}     a job name
#  @param   {buildNumber}  a build number
#  @return  <none>
mustHaveWorkspaceWithArtefactsFromUpstreamProjects() {
    local jobName=$1
    local buildNumber=$2

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace
    info "workspace is ${workspace}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"

    return
}
