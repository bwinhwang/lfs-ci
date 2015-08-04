#!/bin/bash

## @fn      usecase_LFS_RELEASE_SEND_RELEASE_NOTE()
#  @brief   create a release note and send it to the community
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_SEND_RELEASE_NOTE() {
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


