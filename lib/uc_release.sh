#!/bin/bash
## @file  uc_release.sh
#  @brief usecase release 

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion}      ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_jenkins}         ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_workflowtool}    ]] && source ${LFS_CI_ROOT}/lib/workflowtool.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh
[[ -z ${LFS_CI_SOURCE_try}             ]] && source ${LFS_CI_ROOT}/lib/try.sh
[[ -z ${LFS_CI_SOURCE_fingerprint}     ]] && source ${LFS_CI_ROOT}/lib/fingerprint.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @param   <none>
#  @return  <none>
ci_job_release() {
    requiredParameters TESTED_BUILD_JOBNAME TESTED_BUILD_NUMBER
    requiredParameters JOB_NAME BUILD_NUMBER

    info "promoted build is ${TESTED_BUILD_JOBNAME} / ${TESTED_BUILD_NUMBER}"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHavePreparedWorkspace ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER}

    local subJob=$(getSubTaskNameFromJobName)
    mustHaveValue "${subJob}" "subtask name"

    # find the related jobs of the build
    local packageJobName=$(getPackageJobNameFromFingerprint)
    mustHaveValue "${packageJobName}"     "package job name"

    local packageBuildNumber=$(getPackageBuildNumberFromFingerprint)
    mustHaveValue "${packageBuildNumber}" "package build name"

    local buildJobName=$(getBuildJobNameFromFingerprint)
    mustHaveValue "${buildJobName}"       "build job name"

    local buildBuildNumber=$(getBuildBuildNumberFromFingerprint)
    mustHaveValue "${buildBuildNumber}"   "build build number"

    local releaseLabel=$(getNextReleaseLabel)
    mustHaveValue "${releaseLabel}" "release label"

    info "found package job: ${packageJobName} / ${packageBuildNumber}"
    info "found build   job: ${buildJobName} / ${buildBuildNumber}"
    
    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${releaseLabel}
    mustExistDirectory ${releaseDirectory}
    debug "found results of package job on share: ${releaseDirectory}"

    # storing new and old label name into files for later use and archive
    execute mkdir -p ${workspace}/bld/bld-lfs-release/
    echo ${releaseLabel} > ${workspace}/bld/bld-lfs-release/label.txt
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} \
            ${workspace}/bld/bld-lfs-release/label.txt

    local releaseSummaryJobName=${JOB_NAME//${subJob}/summary}
    info "release job name is ${releaseSummaryJobName}"

    # TODO: demx2fk3 2014-08-08 this does not work for reRelease a build. In reRelease usecase, we need
    # the build before the last successful build.
    local lastSuccessfulBuildDirectory=$(getBuildDirectoryOnMaster ${releaseSummaryJobName} lastSuccessfulBuild)
    if runOnMaster test -e ${lastSuccessfulBuildDirectory}/label.txt ; then
        copyFileFromBuildDirectoryToWorkspace ${releaseSummaryJobName} lastSuccessfulBuild label.txt
        execute mv ${WORKSPACE}/label.txt ${workspace}/bld/bld-lfs-release/oldLabel.txt
    else
        # TODO: demx2fk3 2014-08-08 this should be an error message.
        local basedOn=$(getConfig LFS_PROD_uc_release_based_on)
        echo ${basedOn} > ${workspace}/bld/bld-lfs-release/oldLabel.txt
    fi

    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=$(cat ${workspace}/bld/bld-lfs-release/label.txt)
    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME=$(cat ${workspace}/bld/bld-lfs-release/oldLabel.txt)
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL=${LFS_PROD_RELEASE_CURRENT_TAG_NAME//PS_LFS_OS_/PS_LFS_REL_}
    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL=${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME//PS_LFS_OS_/PS_LFS_REL_}
    info "LFS os release ${LFS_PROD_RELEASE_CURRENT_TAG_NAME} is based on ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}"
    info "LFS release ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL} is based on ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL}"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" \
        "<a href=https://wft.inside.nsn.com/ALL/builds/${releaseLabel}>${releaseLabel}</a><br>
         <a href=https://wft.inside.nsn.com/ALL/builds/${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}>${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}</a>"

    info "task is ${subJob}"
    case ${subJob} in
        update_dependency_files)
            updateDependencyFiles "${buildJobName}" "${buildBuildNumber}"
        ;;
        upload_to_subversion)
            local branch=$(getConfig LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch)
            mustHaveValue "${branch}" "branch name"
            # from subversion.sh
            uploadToSubversion "${releaseDirectory}/os" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"
        ;;
        build_results_to_share)
            extractArtifactsOnReleaseShare "${buildJobName}" "${buildBuildNumber}"
        ;;
        build_results_to_share_kernelsources)
            extractArtifactsOnReleaseShareKernelSources "${buildJobName}" "${buildBuildNumber}"
        ;;
        create_release_tag)
            createReleaseTag ${buildJobName} ${buildBuildNumber}
        ;;
        create_proxy_release_tag) 
            # createProxyReleaseTag ${buildJobName} ${buildBuildNumber}
            warning "disabled due to BI#293"
        ;;
        create_source_tag) 
            createTagOnSourceRepository ${buildJobName} ${buildBuildNumber}
        ;;
        pre_release_checks)
            databaseEventReleaseStarted
            prereleaseChecks
        ;;
        summary)
            sendReleaseNote "${TESTED_BUILD_JOBNAME}" "${TESTED_BUILD_NUMBER}" \
                            "${buildJobName}"         "${buildBuildNumber}"
            databaseEventReleaseFinished
            createArtifactArchive
        ;;
        *)
            error "subJob not known (${subJob})"
            exit 1
        ;;
    esac

    return
}


## @fn      extractArtifactsOnReleaseShareKernelSources()
#  @brief   extract the artifacts (linux kernel sources only!!) of build job on the 
#           local workspace and copy the artifacts to the /build share.
#  @details structure on the share is
#           bld-<ss>-<cfg>/<label>/results/...
#  @param   {jobName}      name of the job
#  @param   {buildNumber}  number of the build
#  @return  <none>
extractArtifactsOnReleaseShareKernelSources() {
    local testedJobName=$1
    local testedBuildNumber=$2

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    # TODO: demx2fk3 2015-03-09 FIXME SSH_LOAD replace this with other server
    local server=$(getConfig jenkinsMasterServerHostName)
    mustHaveValue "${server}" "server name"

    local canStoreArtifactsOnShare=$(getConfig LFS_CI_uc_release_can_store_build_results_on_share)

    local labelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${labelName}"

    info "getting down stream information for ${testedJobName} / ${testedBuildNumber}"
    local triggeredJobData=$(getDownStreamProjectsData ${testedJobName} ${testedBuildNumber})
    mustHaveValue "${triggeredJobData}" "triggered job data"

    for jobData in ${triggeredJobData} ; do
        local buildNumber=$(echo ${jobData} | cut -d: -f 1)
        local jobName=$(    echo ${jobData} | cut -d: -f 3-)
        local subTaskName=$(getSubTaskNameFromJobName ${jobName})

        info "checking for ${jobName} / ${buildNumber}"

        # TODO: demx2fk3 2014-10-14 this is wrong!!! it does not handle other branches correcly
        # BUT, the location of the kernel sources are the same on all branches
        case ${subTaskName} in
            FSM-r2) location=trunk      ;;
            FSM-r3) location=trunk      ;;
            FSM-r4) location=FSM_R4_DEV ;;
            LRC)    location=LRC        ;;
            FSM-r3-FSMDDALpdf) continue ;;
            *UT)               continue ;;
            *) fatal "subTaskName ${subTaskName} is not supported" ;;
        esac

        info "creating new workspace to copy kernel sources for ${jobName} / ${location}"
        createBasicWorkspace -l ${location} src-project
        copyArtifactsToWorkspace "${jobName}" "${buildNumber}" "kernelsources"

        local lastKernelLocation=$(build location bld/bld-kernelsources-linux)
        local destinationBaseDirectory=$(dirname ${lastKernelLocation})
        mustExistDirectory ${destinationBaseDirectory}

        local destination=${destinationBaseDirectory}/${labelName}

        [[ ! -d ${workspace}/bld/bld-kernelsources-linux ]] && continue
        [[   -d ${destination}                           ]] && continue

        info "copy kernelsources from ${jobName} to buildresults share ${destination}"

        if [[ ${canStoreArtifactsOnShare} ]] ; then
            # TODO: demx2fk3 2015-03-03 FIXME use execute -r 10 ssh master
            executeOnMaster chmod u+w $(dirname ${destination})
            executeOnMaster mkdir -p  ${destination}
            execute rsync -av --exclude=.svn ${workspace}/bld/bld-kernelsources-linux/. ${server}:${destination}/
            touch ${destination}
        else
            warning "storing artifacts on share is disabled in config"
        fi
    done

    info "clean up workspace"
    execute rm -rf ${workspace}

    return
}

## @fn      sendReleaseNote()
#  @brief   create a release note and send it to the community
#  @param   <none>
#  @return  <none>
sendReleaseNote() {
    requiredParameters LFS_CI_CONFIG_FILE LFS_CI_ROOT

    local testedJobName=$1
    local testedBuildNumber=$2
    local buildJobName=$3
    local buildBuildNumber=$4
    
    # TODO: demx2fk3 2014-06-25 remove the export block and do it in a different way
    # TODO: demx2fk3 2015-05-26 this is required for the perl skript at the moment. The script is using the internal function getConfig, but don't know the used environment variables from the scripting
    export productName=$(getProductNameFromJobName)
    export taskName=$(getTaskNameFromJobName)
    export subTaskName=$(getSubTaskNameFromJobName)
    export location=$(getLocationName)
    export config=$(getTargetBoardName)

    local canSendReleaseNote=$(getConfig LFS_CI_uc_release_can_send_release_note)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local releaseTagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}
    local oldReleaseTagName=${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}
    local osTagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${releaseTagName}" "next release tag name"
    mustHaveValue "${osTagName}" "next os tag name"
    mustHaveValue "${oldReleaseTagName}" "old release tag name"

    # TODO FIME
    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}" "externalComponents fsmpsl psl fsmci lrcpsl"

    info "collect revisions from all sub build jobs"
    sort -u ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt > ${workspace}/revisions.txt

    copyImportantNoteFilesFromSubversionToWorkspace 

    # create the os or uboot release note
    info "new release label is ${releaseTagName} based on ${oldReleaseTagName}"
    _createLfsOsReleaseNote ${buildJobName} ${buildBuildNumber}

    createReleaseInWorkflowTool ${osTagName} ${workspace}/os/os_releasenote.xml
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/os_releasenote.xml
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/releasenote.txt
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/changelog.xml
    uploadToWorkflowTool        ${osTagName} ${workspace}/revisions.txt

    [[ -e ${workspace}/importantNote.txt ]] &&
        uploadToWorkflowTool    ${osTagName} ${workspace}/importantNote.txt

    execute cp -f ${workspace}/os/os_releasenote.xml                                 ${workspace}/bld/bld-lfs-release/lfs_os_releasenote.xml
    execute cp -f ${workspace}/os/releasenote.txt                                    ${workspace}/bld/bld-lfs-release/lfs_os_releasenote.txt
    execute cp -f ${workspace}/os/changelog.xml                                      ${workspace}/bld/bld-lfs-release/lfs_os_changelog.xml
    execute cp -f ${workspace}/revisions.txt                                         ${workspace}/bld/bld-lfs-release/revisions.txt
    execute cp -f ${workspace}/bld/bld-externalComponents-summary/externalComponents ${workspace}/bld/bld-lfs-release/externalComponents.txt
    [[ -e ${workspace}/importantNote.txt ]] &&
        execute cp -f ${workspace}/importantNote.txt                                 ${workspace}/bld/bld-lfs-release/importantNote.txt

    if [[ ${productName} == "LFS" ]] ; then
        _createLfsRelReleaseNoteXml ${releaseTagName} ${workspace}/rel/releasenote.xml
        createReleaseInWorkflowTool ${releaseTagName} ${workspace}/rel/releasenote.xml
        uploadToWorkflowTool        ${releaseTagName} ${workspace}/rel/releasenote.xml

        execute cp -f ${workspace}/rel/releasenote.xml ${workspace}/bld/bld-lfs-release/lfs_rel_releasenote.xml
    fi

    if [[ ${canSendReleaseNote} ]] ; then
        info "send release note"
        execute ${LFS_CI_ROOT}/bin/sendReleaseNote  -r ${workspace}/os/releasenote.txt \
                                                    -t ${releaseTagName}               \
                                                    -f ${LFS_CI_CONFIG_FILE}
    else
        warning "sending the release note is disabled in config"
    fi

    for file in ${workspace}/bld/bld-lfs-release/* ; do
        [[ -f ${file} ]] || continue
        copyFileToArtifactDirectory ${file}
    done

    # TODO: demx2fk3 2014-08-19 fixme - parameter should not be required
    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}

    local remoteDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${osTagName}
    local artifactsPathOnMaster=$(getBuildDirectoryOnMaster)/archive
    executeOnMaster ln -sf ${remoteDirectory} ${artifactsPathOnMaster}/release

    info "release is done."
    return
}


## @fn      copyImportantNoteFilesFromSubversionToWorkspace()
#  @brief   copy the important note files from subversion into workspace if exists
#  @param   <none>
#  @return  <none>
copyImportantNoteFilesFromSubversionToWorkspace() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName 

    local importantNoteFileName=$(getConfig LFS_uc_release_important_note_file)
    mustHaveValue "${importantNoteFileName}" "important note file name"

    mustExistFile ${workspace}/revisions.txt
    local svnUrl=$(execute -n grep ^src-project ${workspace}/revisions.txt | cut -d" " -f 2)
    mustHaveValue "${svnUrl}" "svn url"

    local svnRev=$(execute -n grep ^src-project ${workspace}/revisions.txt | cut -d" " -f 3)
    mustHaveValue "${svnRev}" "svn rev"

    if existsInSubversion "-r ${svnRev} ${svnUrl}/src" release_note &&
       existsInSubversion "-r ${svnRev} ${svnUrl}/src/release_note" ${importantNoteFileName} ; then
        svnCat -r ${svnRev} ${svnUrl}/src/release_note/${importantNoteFileName}@${svnRev} > ${workspace}/importantNote.txt
    fi

    return
}

## @fn      _createLfsOsReleaseNote()
#  @brief   create an PS_LFS_OS release note 
#  @param   {buildJobName}     project name of the build job
#  @param   {buildBuildNumber} build number of the build job   
#  @return  <none>
_createLfsOsReleaseNote() {
    local buildJobName=$1
    local buildBuildNumber=$2

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME LFS_PROD_RELEASE_PREVIOUS_TAG_NAME \
                       LFS_CI_ROOT LFS_CI_CONFIG_FILE \
                       JOB_NAME BUILD_NUMBER \

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName 

    # get the change log file from master
    local buildDirectory=$(getBuildDirectoryOnMaster ${JOB_NAME} ${BUILD_NUMBER})
    # TODO: demx2fk3 2015-03-09 FIXME SSH_LOAD replace this with other server
    local serverName=$(getConfig jenkinsMasterServerHostName)

    info "creating release note for ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}"
    
    execute mkdir -p ${workspace}/os
    mustExistDirectory ${workspace}/os
    # TODO: demx2fk3 2015-03-09 FIXME SSH_LOAD replace this with other server
    execute -r 10 rsync -ae ssh ${serverName}:${buildDirectory}/changelog.xml ${workspace}/os/
    mustExistFile ${workspace}/os/changelog.xml

    # convert the changelog xml to a release note
    cd ${workspace}/os/
    execute ln -sf ../bld .
    execute rm -f releasenote.txt releasenote.xml

    export tagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteContent -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME} > releasenote.txt
    rawDebug ${workspace}/os/releasenote.txt

    export type=OS

    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}  \
                                                    -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} \
                                                    -f ${LFS_CI_CONFIG_FILE} > releasenote.xml
    rawDebug ${workspace}/os/releasenote.xml
    execute mv -f ${workspace}/os/releasenote.xml ${workspace}/os/os_releasenote.xml

    mustBeValidXmlReleaseNote ${workspace}/os/os_releasenote.xml

    unset type
    export type

    return
}

## @fn      _createLfsRelReleaseNoteXml()
#  @brief   create an PSLFS_REL release note 
#  @param   {buildJobName}     project name of the build job
#  @param   {buildBuildNumber} build number of the build job   
#  @return  <none>
_createLfsRelReleaseNoteXml() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    requiredParameters LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL \
                       LFS_PROD_RELEASE_PREVIOUS_TAG_NAME LFS_CI_ROOT LFS_CI_CONFIG_FILE

    info "creating release note xml for ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}"
    execute mkdir -p ${workspace}/rel/bld/bld-externalComponents-summary
    cd ${workspace}/rel/
    execute -n grep sdk ${workspace}/bld/bld-externalComponents-summary/externalComponents \
                      > ${workspace}/rel/bld/bld-externalComponents-summary/externalComponents

    echo "PS_LFS_OS <> = ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}" >> ${workspace}/rel/bld/bld-externalComponents-summary/externalComponents

    # no changes here, just a dummy changelog is required
    echo '<log />' > changelog.xml 

    export tagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    export type=REL
    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}  \
                                                    -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL} \
                                                    -f ${LFS_CI_CONFIG_FILE} > releasenote.xml
    rawDebug ${workspace}/releasenote.xml
    unset type
    export type

    return
}


## @fn      createTagOnSourceRepository()
#  @brief   create a tag(s) on source repository 
#  @details create tags in the source repository (os/tags) and subsystems (subsystems/tags)
#  @param   {jobName}        a job name
#  @param   {buildNumber}    a build number
#  @param   <none>
#  @return  <none>
createTagOnSourceRepository() {
    local jobName=$1
    local buildNumber=$2

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME

    local workspace=$(getWorkspaceName)
    local requiredArtifacts=$(getConfig LFS_CI_UC_release_required_artifacts)
    mustHaveWorkspaceWithArtefactsFromUpstreamProjects "${jobName}" "${buildNumber}" "externalComponents"

    local osLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    export tagName=${osLabelName}
    local svnUrl=$(getConfig lfsSourceRepos)
    local svnUrlOs=${svnUrl}/os
    local branch=pre_${osLabelName}
    local logMessage=$(createTempFile)

    local canCreateSourceTag=$(getConfig LFS_CI_uc_release_can_create_source_tag)

    svnUrlOs=$(normalizeSvnUrl ${svnUrlOs})
    svnUrl=$(normalizeSvnUrl ${svnUrl})
    mustHaveValue "${svnUrl}" "svnUrl"
    mustHaveValue "${svnUrlOs}" "svnUrlOs"

    #                          _                                
    #                      ___| | ___  __ _ _ __    _   _ _ __  
    #                     / __| |/ _ \/ _` | '_ \  | | | | '_ \ 
    #                    | (__| |  __/ (_| | | | | | |_| | |_) |
    #                     \___|_|\___|\__,_|_| |_|  \__,_| .__/ 
    #                                                    |_|    
    # TODO cleanup this part of the code
    # * it's do long
    # * it is not clean

    info "using lfs os ${osLabelName}"
    info "using repos ${svnUrlOs}/branches/${branch}"
    info "using repos for new tag ${svnUrlOs}/tags/${osLabelName}"
    info "using repos for package ${svnUrl}/subsystems/"

    # get os label
    local osLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${osLabelName}" "no os label name"

    execute mkdir -p ${workspace}/rev/

    for revisionFile in ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt ; do
        [[ -e ${revisionFile} ]] || continue

        rawDebug "${revisionFile}"

        local dirName=$(basename $(dirname ${revisionFile}))
        export cfg=$(cut -d- -f3 <<< ${dirName})
        local tagDirectory=$(getConfig LFS_PROD_uc_release_source_tag_directory)
        info "using tag dir ${tagDirectory} for cfg ${cfg}"
        unset cfg ; export cfg

        execute -n sort -u ${revisionFile} ${workspace}/rev/${tagDirectory} > ${workspace}/rev/${tagDirectory}

        rawDebug ${workspace}/rev/${tagDirectory}
    done

    # check for branch

    if existsInSubversion ${svnUrlOs}/tags ${osLabelName} ; then
        error "tag ${osLabelName} already exists"
        exit 1
    fi

    if existsInSubversion ${svnUrlOs}/branches ${branch} ; then
        info "removing branch ${branch}"
        svnRemove -m removing_branch_for_production ${svnUrlOs}/branches/${branch} 
    fi

    mustExistBranchInSubversion ${svnUrlOs}/branches ${branch}
    # mustExistBranchInSubversion ${svnUrlOs}/tags ${branch}

    for revisionFile in ${workspace}/rev/* ; do
        [[ -e ${revisionFile} ]] || continue

        export target=$(basename ${revisionFile})
        local tagPrefix=$(getConfig LFS_PROD_uc_release_source_tag_prefix)

        mustExistBranchInSubversion ${svnUrlOs}/branches/${branch} ${target}

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
                src-*) dirname=${src} ;;
                *)     dirname=$(dirname ${src})
                       mustExistBranchInSubversion ${svnUrlOs}/branches/${branch}/${target} ${dirname}
                ;;
            esac

            info "copy ${src} to ${branch}/${target}/${dirname}"
            svnCopy -r ${rev} -m branching_src_${src}_to_${branch} \
                ${normalizedUrl}                                   \
                ${svnUrlOs}/branches/${branch}/${target}/${dirname}

            case ${src} in
                src-*)
                    if ! existsInSubversion ${svnUrl}/subsystems/${src}/ ${tagPrefix}${osLabelName} ; then
                        svnCopy -m tag_for_package_src_${src} ${svnUrlOs}/branches/${branch}/${target}/${src} \
                            ${svnUrl}/subsystems/${src}/${tagPrefix}${osLabelName}
                        trace "CLEANUP svn rm -m cleanup ${svnUrl}/subsystems/${src}/${tagPrefix}${osLabelName}"
                    fi
                ;;
            esac

        done < ${revisionFile}
    done


    # check for the branch
    info "svn repos url is ${svnUrl}/branches/${branch}"

    if [[ ${canCreateSourceTag} ]] ; then

        svnCopy -m create_new_tag_${osLabelName} \
            ${svnUrl}/os/branches/${branch}      \
            ${svnUrl}/os/tags/${osLabelName}

        info "branch ${branch} no longer required, removing branch"
        svnRemove -m removing_branch_for_production ${svnUrlOs}/branches/${branch} 
    else
        warning "creating a source tag is disabled in config"
    fi

    info "tagging done"

    return
}


## @fn      mustHaveWorkspaceWithArtefactsFromUpstreamProjects()
#  @brief   ensures, that a new workspace will be created with artifacts of the upstream project
#  @param   {jobsName}     a job name
#  @param   {buildNumber}  a build number
#  @return  <none>
mustHaveWorkspaceWithArtefactsFromUpstreamProjects() {
    local jobName=$1
    local buildNumber=$2
    local allowedComponents=$3

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace
    info "workspace is ${workspace}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}" "${allowedComponents}"

    return
}

## @fn      updateDependencyFiles()
#  @brief   update the dependency files for all components of a build
#  @param   {jobName}        name of the build job
#  @param   {buildNumber}    numfer of the build job
#  @return  <none>
updateDependencyFiles() {
    local jobName=$1
    local buildNumber=$2

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWorkspaceWithArtefactsFromUpstreamProjects ${jobName} ${buildNumber} "externalComponents"

    local componentsFile=$(createTempFile)
    execute -n sort -u ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt > ${componentsFile}

    local releaseLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    local oldReleaseLabelName=${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}
    # without the old label name, the Dependencies file will be destroyed
    mustHaveValue "${oldReleaseLabelName}" "old release label name"
    local canCommitDependencies=$(getConfig LFS_CI_uc_release_can_commit_depencencies)

    info "using values: old value: ${oldReleaseLabelName} new value: ${releaseLabelName}"
    while read name url rev ; do

        case ${name} in
            src-*) :        ;; # ok
            *)     continue ;; # not ok, skip
        esac

        info "updating Dependencies and Revisions for ${name} "
        debug "from file: ${name} ${url} ${rev}"

        execute rm -rf ${workspace}/${name}
        svnCheckout --depth=immediates --ignore-externals ${url} ${workspace}/${name}
        local dependenciesFile=${workspace}/${name}/Dependencies

        if [[ ! -e ${dependenciesFile} ]] ; then
            info "file ${dependenciesFile} does not exist"
            continue
        fi
        
        info "update ${name}/Dependencies";
        execute perl -p -i -e "s/\b${oldReleaseLabelName}\b/${releaseLabelName}/g" ${dependenciesFile}
        svnDiff ${dependenciesFile}

        if [[ ${canCommitDependencies} ]] ; then 
            info "running svn commit"
            local logMessage=$(createTempFile)
            local svnCommitMessage=$(getConfig LFS_PROD_uc_release_svn_message_template -t releaseName:${releaseLabelName} -t oldReleaseName:${oldReleaseLabelName} -t revision:${rev} )
            echo ${svnCommitMessage} > ${logMessage}
            svnCommit -F ${logMessage} ${dependenciesFile}
        else
            warning "committing of dependencies is disabled in config"
        fi

        
    done < ${componentsFile}

    info "update done."

    return
}

