#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

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

    local serverPath=$(getConfig jenkinsMasterServerPath)
    mustHaveValue "${serverPath}" "server path"
    mustExistDirectory ${serverPath}

    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    local location=$(getLocationName)
    mustHaveLocationName

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"

    # TODO: demx2fk3 2014-07-11 replace this with getConfig
    local branch=${locationToSubversionMap["${productName}_${location}"]}
    mustHaveValue "${branch}" "branch name"

    # find the related jobs of the build

    local packageJobName=$(getPackageJobNameFromUpstreamProject ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER})
    local packageBuildNumber=$(getPackageBuildNumberFromUpstreamProject ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER})
    local buildJobName=$(getBuildJobNameFromUpstreamProject ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER})
    local buildBuildNumber=$(getBuildBuildNumberFromUpstreamProject ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER})
    mustHaveValue "${packageJobName}"     "package job name"
    mustHaveValue "${packageBuildNumber}" "package build name"
    mustHaveValue "${buildJobName}"       "build job name"
    mustHaveValue "${buildBuildNumber}"   "build build number"

    # release label is stored in the artifacts of fsmci of the build job
    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}" "fsmci"
    mustHaveNextLabelName
    local releaseLabel=$(getNextReleaseLabel)
    mustHaveValue "${releaseLabel}" "release label"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${releaseLabel}<br>${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}"

    info "found package job: ${packageJobName} / ${packageBuildNumber}"
    info "found build   job: ${buildJobName} / ${buildBuildNumber}"
    
    local ciBuildShare=$(getConfig LFS_CI_UC_package_internal_link)
    local releaseDirectory=${ciBuildShare}/build_${packageBuildNumber}
    mustExistSymlink ${releaseDirectory}
    local releaseDirectoryLinkDestination=$(readlink -f ${releaseDirectory})
    mustExistDirectory ${releaseDirectoryLinkDestination}

    debug "found results of package job on share: ${releaseDirectory}"

    # storing new and old label name into files for later use and archive
    execute mkdir -p ${workspace}/bld/bld-lfs-release/
    echo ${releaseLabel} > ${workspace}/bld/bld-lfs-release/label.txt
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} \
            ${workspace}/bld/bld-lfs-release/label.txt

    local releaseSummaryJobName=${JOB_NAME//${subJob}/summary}
    info "release job name is ${releaseSummaryJobName}"

    # TODO: demx2fk3 2014-08-08 this does not work for reRelease a build. In reReleas usecase, we need
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

    info "task is ${subJob}"
    case ${subJob} in
        update_dependency_files)
            updateDependencyFiles "${buildJobName}" "${buildBuildNumber}"
        ;;
        upload_to_subversion)
            # from subversion.sh
            uploadToSubversion "${releaseDirectory}/os" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"
        ;;
        build_results_to_share)
            extractArtifactsOnReleaseShare "${buildJobName}" "${buildBuildNumber}"
        ;;
        create_release_tag)
            createReleaseTag ${buildJobName} ${buildBuildNumber}
        ;;
        create_proxy_release_tag) 
            createProxyReleaseTag ${buildJobName} ${buildBuildNumber}
        ;;
        create_source_tag) 
            createTagOnSourceRepository ${buildJobName} ${buildBuildNumber}
        ;;
        pre_release_checks)
            prereleaseChecks
        ;;
        summary)
            sendReleaseNote "${TESTED_BUILD_JOBNAME}" "${TESTED_BUILD_NUMBER}" \
                            "${buildJobName}"         "${buildBuildNumber}"
        ;;
        *)
            error "subJob not known (${subJob})"
            exit 1
        ;;
    esac

    return
}

prereleaseChecks() {

    local exitCode=0
    if ! _existsBaselineInWorkflowTool ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} ; then
        error "previous Version ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} does not exist in WFT"
        exitCode=1
    fi
    if [[ $(getProductNameFromJobName) =~ LFS ]] ; then
        if ! _existsBaselineInWorkflowTool ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL} ; then
            error "previous Release Version ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL} does not exist in WFT"
            exitCode=1
        fi                
    fi

    exit ${exitCode}
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

    requiredParameters LFS_PROD_RELEASE_PREVIOUS_TAG_NAME LFS_PROD_RELEASE_CURRENT_TAG_NAME

    local workspace=$(getWorkspaceName)
    local server=$(getConfig jenkinsMasterServerHostName)
    local resultBuildShare=$(getConfig LFS_PROD_UC_release_copy_build_to_share)
    local resultBuildShareLinuxKernel=$(getConfig LFS_PROD_UC_release_copy_build_to_share_linux_kernel)
    mustHaveWorkspaceName

    local canStoreArtifactsOnShare=$(getConfig LFS_CI_uc_release_can_store_build_results_on_share)

    local labelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${labelName}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"

    cd ${workspace}/bld/
    for dir in bld-*-* ; do
        [[ -d ${dir} ]] || continue
        basename=$(basename ${dir})

        local destination=${resultBuildShare}/${basename}/${labelName}
        if [[ ${basename} =~ kernelsources ]] ; then
            # TODO: demx2fk3 2014-08-07 use different dir for fsmr4
            if [[ ${basename} =~ fsm4_ ]] ; then
                destination=${resultBuildShareLinuxKernel}/FSMR4_${labelName}
            else
                destination=${resultBuildShareLinuxKernel}/${labelName}
            fi
            executeOnMaster chmod u+w ${resultBuildShareLinuxKernel}/
            warning "skipping kernel sources - copy to share is broken at the moment"
            continue
        fi

        info "copy ${basename} to buildresults share ${destination}"

        if [[ ${canStoreArtifactsOnShare} ]] ; then
            executeOnMaster chmod u+w ${resultBuildShare}/
            executeOnMaster mkdir -p ${resultBuildShare}/${basename}/
            executeOnMaster chmod u+w ${resultBuildShare}/${basename}/
            executeOnMaster mkdir -p ${destination}
            execute rsync -av --exclude=.svn ${workspace}/bld/${basename}/. ${server}:${destination}
            touch ${destination}
        else
            warning "storing artifacts on share is disabled in config"
        fi
    done

    info "clean up workspace"
    execute rm -rf ${workspace}/bld

    return
}

## @fn      sendReleaseNote()
#  @brief   create a release note and send it to the community
#  @param   <none>
#  @return  <none>
sendReleaseNote() {
    local testedJobName=$1
    local testedBuildNumber=$2
    local buildJobName=$3
    local buildBuildNumber=$4
    
    # TODO: demx2fk3 2014-06-25 remove the export block and do it in a different way
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

    # create the os or uboot release note
    info "new release label is ${releaseTagName} based on ${oldReleaseTagName}"
    _createLfsOsReleaseNote ${buildJobName} ${buildBuildNumber}

    info "collect revisions from all sub build jobs"
    sort -u ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt > ${workspace}/revisions.txt

    _createReleaseInWorkflowTool ${osTagName} ${workspace}/os/os_releasenote.xml
    _uploadToWorkflowTool        ${osTagName} ${workspace}/os/os_releasenote.xml
    _uploadToWorkflowTool        ${osTagName} ${workspace}/os/releasenote.txt
    _uploadToWorkflowTool        ${osTagName} ${workspace}/os/changelog.xml
    _uploadToWorkflowTool        ${osTagName} ${workspace}/revisions.txt

    execute cp -f ${workspace}/os/os_releasenote.xml                                 ${workspace}/bld/bld-lfs-release/lfs_os_releasenote.xml
    execute cp -f ${workspace}/os/releasenote.txt                                    ${workspace}/bld/bld-lfs-release/lfs_os_releasenote.txt
    execute cp -f ${workspace}/os/changelog.xml                                      ${workspace}/bld/bld-lfs-release/lfs_os_changelog.xml
    execute cp -f ${workspace}/revisions.txt                                         ${workspace}/bld/bld-lfs-release/revisions.txt
    execute cp -f ${workspace}/bld/bld-externalComponents-summary/externalComponents ${workspace}/bld/bld-lfs-release/externalComponents.txt

    if [[ ${productName} == "LFS" ]] ; then
        _createLfsRelReleaseNoteXml  ${releaseTagName} ${workspace}/rel/releasenote.xml
        _createReleaseInWorkflowTool ${releaseTagName} ${workspace}/rel/releasenote.xml
        _uploadToWorkflowTool        ${releaseTagName} ${workspace}/rel/releasenote.xml

        execute cp -f ${workspace}/rel/releasenote.xml ${workspace}/bld/bld-lfs-release/lfs_rel_releasenote.xml
    fi

    if [[ ${canSendReleaseNote} ]] ; then
        info "send release note"
        execute ${LFS_CI_ROOT}/bin/sendReleaseNote  -r ${workspace}/os/releasenote.txt \
                                                    -t ${releaseTagName}               \
                                                    -f ${LFS_CI_ROOT}/etc/file.cfg
    else
        warning "sending the release note is disabled in config"
    fi

    for file in ${workspace}/bld/bld-lfs-release/* ; do
        [[ -f ${file} ]] || continue
        copyFileToArtifactDirectory ${file}
    done

    # TODO: demx2fk3 2014-08-19 fixme - parameter should not be required
    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    createSymlinksToArtifactsOnShare ${artifactsPathOnShare}

    # TODO: demx2fk3 2014-08-19 fixme - make this in a nicer way
    info "creating approval file on moritz for ${osTagName}"
    execute ssh moritz touch /lvol2/production_jenkins/tmp/approved/${osTagName}

    local artifactsPathOnMaster=$(getBuildDirectoryOnMaster)/archive
    local remoteDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${osTagName}
    executeOnMaster ln -sf ${remoteDirectory} ${artifactsPathOnMaster}/release

    info "release is done."
    return
}

_createReleaseInWorkflowTool() {
    local tagName=$1
    local fileName=$2
    mustExistFile ${fileName}

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local wftApiKey=$(getConfig WORKFLOWTOOL_api_key)
    local wftCreateRelease=$(getConfig WORKFLOWTOOL_url_create_release)
    local curl="curl -k ${wftCreateRelease} -F access_key=${wftApiKey}" 

    local canCreateReleaseInWorkflowTool=$(getConfig LFS_CI_uc_release_can_create_release_in_wft)
    if [[ ! ${canCreateReleaseInWorkflowTool} ]] ; then
        warning "creating release in WFT is disabled via config"
        return
    fi

    # check, if wft already knows about the release
    local update=""
    if _existsBaselineInWorkflowTool ${tagName} ; then
        update="-F update=yes"  # does exist
    else
        update="-F update=no" # does not exist 
    fi

    info "creating release based on ${fileName} in wft"
    execute ${curl} ${update} -F file=@${fileName}
    echo "${curl} ${update} -F file=@${fileName}" >> ${workspace}/redo.sh

    if ! _existsBaselineInWorkflowTool ${tagName} ; then
        error "just created baseline ${tagName} does not exist in WFT"
        exit 1
    fi

    return
}

_uploadToWorkflowTool() {
    local tagName=$1
    local fileName=$2
    mustExistFile ${fileName}

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local wftApiKey=$(getConfig WORKFLOWTOOL_api_key)
    local wftUploadAttachment=$(getConfig WORKFLOWTOOL_url_upload_attachment)
    local curl="curl -k ${wftUploadAttachment}/${tagName} -F access_key=${wftApiKey} "

    local canCreateReleaseInWorkflowTool=$(getConfig LFS_CI_uc_release_can_create_release_in_wft)
    if [[ ! ${canCreateReleaseInWorkflowTool} ]] ; then
        warning "uploading release note / file in WFT is disabled via config"
        return
    fi

    if [[ ! -s ${fileName} ]] ; then
        debug "file ${fileName} is empty"
        return
    fi

    local update=""
    if _existsBaselineInWorkflowTool ${tagName} ; then
        update="-F update=yes"  # does exist
    else
        update="-F update=no" # does not exist 
    fi

    info "uploading ${fileName} to wft"
    execute ${curl} ${update} -F file=@${fileName}
    echo "${curl} ${update} -F file=@${fileName}" >> ${workspace}/redo.sh

    return
}

_existsBaselineInWorkflowTool() {
    local tagName=$1

    local wftApiKey=$(getConfig WORKFLOWTOOL_api_key)
    local wftBuildContent=$(getConfig WORKFLOWTOOL_url_build_content)
    local curl="curl -k ${wftUploadAttachment}/${tagName} -F access_key=${wftApiKey} "

    # check, if wft already knows about the release
    curl -sf -k ${wftBuildContent}/${tagName} >/dev/null 
    case $? in 
        # reverse logic due to exit code logic: 1 == failure, 0 == ok
        0)  return 0 ;; # does exist
        22) return 1 ;; # does not exist 
        *)  error "unknown error from curl $?"; exit 1 ;;
    esac

    # not reachable
    exit 1
}

_validateReleaseNoteXml() {
    local releaseNoteXml=$1

    # check with wft
    info "validating release note"
    local wftApiKey=$(getConfig WORKFLOWTOOL_api_key)
    local wftReleaseNoteValidate=$(getConfig WORKFLOWTOOL_url_releasenote_validation)
    local wftReleaseNoteXsd=$(getConfig WORKFLOWTOOL_url_releasenote_xsd)

#    if [[ ! ${canCreateReleaseInWorkflowTool} ]] ; then
#        warning "validating release note xml in WFT is disabled via config"
#        return
#    fi

    if [[ ${wftReleaseNoteXsd} ]] ; then
        # local check first
        execute rm -f releasenote.xsd
        execute curl -k ${wftReleaseNoteXsd} --output releasenote.xsd
        mustExistFile releasenote.xsd

        execute xmllint --schema releasenote.xsd ${releaseNoteXml}
    fi

    # remove check with wft next
    local outputFile=$(createTempFile)
    execute curl -k ${wftReleaseNoteValidate} \
                 -F access_key=${wftApiKey}   \
                 -F file=@${releaseNoteXml}   \
                 --output ${outputFile}
    rawDebug ${outputFile}

    if ! grep -q "XML valid" ${outputFile} ; then
        error "release note xml ${releaseNoteXml} is not valid"
        exit 1
    fi
        
    return
}

_createLfsOsReleaseNote() {
    local buildJobName=$1
    local buildBuildNumber=$2

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME LFS_PROD_RELEASE_PREVIOUS_TAG_NAME LFS_CI_ROOT \
                       JOB_NAME BUILD_NUMBER

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName 

    # get the change log file from master
    local buildDirectory=$(getBuildDirectoryOnMaster ${JOB_NAME} ${BUILD_NUMBER})
    local serverName=$(getConfig jenkinsMasterServerHostName)

    info "creating release note for ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}"
    
    execute mkdir -p ${workspace}/os
    mustExistDirectory ${workspace}/os
    execute rsync -ae ssh ${serverName}:${buildDirectory}/changelog.xml ${workspace}/os/
    mustExistFile ${workspace}/os/changelog.xml

    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}" "externalComponents fsmpsl psl fsmci"

    # convert the changelog xml to a release note
    cd ${workspace}/os/
    execute ln -sf ../bld .
    execute rm -f releasenote.txt releasenote.xml

    export tagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    debug "${LFS_CI_ROOT}/bin/getReleaseNoteContent -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME} > releasenote.txt"
    ${LFS_CI_ROOT}/bin/getReleaseNoteContent -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME} > releasenote.txt
    mustBeSuccessfull "$?" "getReleaseNoteContent"
    rawDebug ${workspace}/os/releasenote.txt

    export type=OS

    debug " ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME} -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} -r http://foobar/asdf/ -f ${LFS_CI_ROOT}/etc/file.cfg > releasenote.xml"
    ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}  \
                                         -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} \
                                         -r http://foobar/asdf/ \
                                         -f ${LFS_CI_ROOT}/etc/file.cfg > releasenote.xml
    mustBeSuccessfull "$?" "getReleaseNoteXML"
    rawDebug ${workspace}/os/releasenote.xml
    execute mv -f ${workspace}/os/releasenote.xml ${workspace}/os/os_releasenote.xml

    _validateReleaseNoteXml ${workspace}/os/os_releasenote.xml

    unset type
    export type

    return
}

_createLfsRelReleaseNoteXml() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    requiredParameters LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL \
                       LFS_PROD_RELEASE_PREVIOUS_TAG_NAME LFS_CI_ROOT

    info "creating release note xml for ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}"
    execute mkdir -p ${workspace}/rel/bld/bld-externalComponents-summary
    cd ${workspace}/rel/
    grep sdk ${workspace}/bld/bld-externalComponents-summary/externalComponents \
            > ${workspace}/rel/bld/bld-externalComponents-summary/externalComponents
    mustBeSuccessfull "$?" "grep sdk ok"

    echo "PS_LFS_OS <> = ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}" >> ${workspace}/rel/bld/bld-externalComponents-summary/externalComponents

    # no changes here, just a dummy changelog is required
    echo '<log />' > changelog.xml 

    export tagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    export type=REL
    ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}  \
                                         -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL} \
                                         -f ${LFS_CI_ROOT}/etc/file.cfg > releasenote.xml
    mustBeSuccessfull "$?" "getReleaseNoteXML"
    rawDebug ${workspace}/releasenote.xml
    unset type
    export type

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


        sort -u ${revisionFile} ${workspace}/rev/${tagDirectory} > ${workspace}/rev/${tagDirectory}
        mustBeSuccessfull "$?" "sort -u"

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
    mustExistBranchInSubversion ${svnUrlOs}/tags ${branch}

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
                *) dirname=$(dirname ${src})
                   mustExistBranchInSubversion ${svnUrlOs}/branches/${branch}/${target} ${dirname}
                ;;
            esac

            info "copy ${src} to ${branch}/${target}/${dirname}"
            svnCopy -r ${rev} -m branching_src_${src}_to_${branch} \
                ${normalizedUrl}                                   \
                ${svnUrlOs}/branches/${branch}/${target}/${dirname}

            case ${src} in
                src-*)
                    svnCopy -m tag_for_package_src_${src} ${svnUrlOs}/branches/${branch}/${target}/${src} \
                        ${svnUrl}/subsystems/${src}/${tagPrefix}${osLabelName}
                    trace "CLEANUP svn rm -m cleanup ${svnUrl}/subsystems/${src}/${tagPrefix}${osLabelName}"
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

    local requiredArtifacts=$(getConfig LFS_CI_UC_release_required_artifacts)
    mustHaveWorkspaceWithArtefactsFromUpstreamProjects "${jobName}" "${buildNumber}" "${requiredArtifacts}"

    local canCreateReleaseTag=$(getConfig LFS_CI_uc_release_can_create_release_tag)

    # get os label
    # no mustHaveNextLabelName, because it's already calculated
    local osLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    local osReleaseLabelName=$(sed "s/_LFS_OS_/_LFS_REL_/" <<< ${osLabelName} )
    mustHaveValue "${osLabelName}" "no os label name"

    # check for branch
    # TODO: demx2fk3 2014-07-08 this is not a nice way to do this, but there
    # is no other way at the moment
    # better: getConfig kayName -t tagName=${osLabelName}
    export tagName=${osLabelName}
    local svnUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url)
    local svnRepoName=$(getConfig LFS_PROD_svn_delivery_repos_name)
    unset tagName

    local branch=$(getBranchName)
    mustHaveBranchName

    # get sdk label
    componentsFile=${workspace}/bld/bld-externalComponents-summary/externalComponents   
    mustExistFile ${componentsFile}

    local sdk2=$(getConfig sdk2 ${componentsFile})
    local sdk3=$(getConfig sdk3 ${componentsFile})
    local sdk=$(getConfig sdk ${componentsFile})

    info "using sdk2 ${sdk2}"
    info "using sdk3 ${sdk3}"
    info "using sdk ${sdk}"
    info "using lfs os ${osLabelName}"
    info "using lfs rel ${osReleaseLabelName}"

    # check for the branch
    info "svn repos url is ${svnUrl}/branches/${branch}"
    mustExistBranchInSubversion ${svnUrl} tags 
    mustExistBranchInSubversion ${svnUrl} branches 
    shouldNotExistsInSubversion ${svnUrl}/tags/ "${osReleaseLabelName}"

    if ! existsInSubversion ${svnUrl}/branches ${branch} ; then
        local logMessage=$(createTempFile)
        echo "BTSPS-1657 IN rh: DESRIPTION: NOJCHK creating a new branch ${branch}" > ${logMessage}
        svnMkdir -F ${logMessage} ${svnUrl}/branches/${branch} 
    fi

    # update svn:externals
    # TODO: demx2fk3 2014-07-09 fixme do this in a different way - more configurable
    local svnExternalsFile=$(createTempFile)
    echo "/isource/svnroot/${svnRepoName}/os/tags/${osLabelName} os " >> ${svnExternalsFile}

    if [[ ${sdk3} ]] ; then 
        echo "/isource/svnroot/BTS_D_SC_LFS_SDK_1/sdk/tags/${sdk3} sdk3" >> ${svnExternalsFile}
    elif [[ ${sdk} ]] ; then
        echo "/isource/svnroot/BTS_D_SC_LFS_SDK_1/sdk/tags/${sdk} sdk3" >> ${svnExternalsFile}
    fi

#    if [[ ${sdk2} ]] ; then 
#        echo "/isource/svnroot/BTS_D_SC_LFS/sdk/tags/${sdk2} sdk2" >> ${svnExternalsFile}
#    fi

    # commit
    info "updating svn:externals"
    svnCheckout --ignore-externals ${svnUrl}/branches/${branch} ${workspace}/svn

    cd ${workspace}/svn
    svnPropSet svn:externals -F ${svnExternalsFile} .
    local logMessage=$(createTempFile)
    echo "BTSPS-1657 IN rh: DESRIPTION: NOJCHK : updating svn:externals for ${osReleaseLabelName}" > ${logMessage}
    svnCommit -F ${logMessage} .

    # make a tag
    info "create tag ${osReleaseLabelName}"
    if [[ ${canCreateReleaseTag} ]] ; then
        local logMessage=$(createTempFile)
        echo "BTSPS-1657 IN rh: DESRIPTION: NOJCHK : create new tag ${osReleaseLabelName}" > ${logMessage}
        svnCopy -F ${logMessage} ${svnUrl}/branches/${branch} ${svnUrl}/tags/${osReleaseLabelName}
    else
        warning "creating the release tag is disabled in config"
    fi

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
    local allowedComponents=$3

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace
    info "workspace is ${workspace}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}" "${allowedComponents}"

    return
}

## @fn      createProxyReleaseTag()
#  @brief   «brief description»
#  @warning «anything important»
#  @details «full description»
#  @todo    «description of incomplete business»
#  @param   {tagName}    name of the tag
#  @param   {reposName}  name of the svn repos
#  @return  <none>
createProxyReleaseTag() {
    export tagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    local relTagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}
    local reposName=$(getConfig LFS_PROD_svn_delivery_repos_name)
    local proxySvnUrl=$(getConfig LFS_PROD_svn_delivery_proxy_repos_url)
    local deliverySvnUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url)

    # TODO: demx2fk3 2014-07-11 replace this with getConfig
    local branch=${locationToSubversionMap["${productName}_${location}"]}
    mustHaveValue "${branch}" "branch name"

    local branchName=${branch}_proxyBranchForCreateTag
    local canCreateProxyTag=$(getConfig LFS_CI_uc_release_can_create_proxy_tag)
    local externals=$(createTempFile)
    local logMessage=$(createTempFile)

    export tagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    info "create proxy tag ${relTagName} in ${proxySvnUrl}"
    info "using ${deliverySvnUrl}"

    mustExistBranchInSubversion ${proxySvnUrl} branches 
    mustExistBranchInSubversion ${proxySvnUrl} tags 
    mustExistBranchInSubversion ${proxySvnUrl}/branches ${branchName}

    svn pg svn:externals ${deliverySvnUrl}/tags/${relTagName} > ${externals}
    mustBeSuccessfull "$?" "svn pg svn:externals command"
    rawDebug ${externals}

    svnCheckout --ignore-externals ${proxySvnUrl}/branches/${branchName} ${workspace}/proxyTag
    svnPropSet svn:externals -F ${externals} ${workspace}/proxyTag

    echo "upBTSPS-1657 IN rh: DESRIPTION: NOJCHK : updating svn:externals using extnerals from ${deliverySvnUrl}/tags/${relTagName}" > ${logMessage}
    svnCommit -F ${logMessage} ${workspace}/proxyTag

    # TODO: demx2fk3 2014-08-08 add a check for svn:externals
    sleep 60

    if [[ ${canCreateProxyTag} ]] ; then
        echo "BTSPS-1657 IN rh: DESRIPTION: NOJCHK : creating new proxy tag ${tagName}" > ${logMessage}
        svnCopy -F ${logMessage} ${proxySvnUrl}/branches/${branchName} ${proxySvnUrl}/tags/${relTagName}
    else
        warning "creating a proxy tag is disabled in config"
    fi

    info "creating proxy tag done."

    return
}

## @fn      updateDependencyFiles( $jobName, $buildNumber )
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
    sort -u ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt > ${componentsFile}

    local releaseLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    local oldReleaseLabelName=${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}
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
            echo "BTSPS-1657 IN psulm: DESCRIPTION: set Dependencies for Release ${releaseLabelName} r${rev} NOJCHK"  > ${logMessage}
            svnCommit -F ${logMessage} ${dependenciesFile}
        else
            warning "committing of dependencies is disabled in config"
        fi

        
    done < ${componentsFile}

    info "update done."

    return
}
