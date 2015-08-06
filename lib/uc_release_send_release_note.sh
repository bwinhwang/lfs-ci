#!/bin/bash

## @fn      usecase_LFS_RELEASE_SEND_RELEASE_NOTE()
#  @brief   create a release note and send it to the community
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_SEND_RELEASE_NOTE() {
    # TODO: demx2fk3 2015-08-05 add externalComponents fsmpsl psl fsmci lrcpsl from to artifacts
    mustBePreparedForReleaseTask

    _workflowToolCreateRelease
    _sendReleaseNote
    _storeArtifactsFromRelease

    info "release is done."

    return
}

## @fn      _storeArtifactsFromRelease()
#  @brief   store the artifacts for the release process
#  @param   <none>
#  @return  <none>
_storeArtifactsFromRelease() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    for file in ${workspace}/bld/bld-lfs-release/* ; do
        [[ -f ${file} ]] || continue
        copyFileToArtifactDirectory ${file}
    done

    # TODO: demx2fk3 2014-08-19 fixme - parameter should not be required
    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}

    # TODO: demx2fk3 2015-08-05 create a own function for this
    local remoteDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    local artifactsPathOnMaster=$(getBuildDirectoryOnMaster)/archive
    executeOnMaster ln -sf ${remoteDirectory} ${artifactsPathOnMaster}/release

    return
}

## @fn      _sendReleaseNote()
#  @brief   send the release note mail to the mailinglist
#  @param   <none>
#  @return  <none>
_sendReleaseNote() {

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local canSendReleaseNote=$(getConfig LFS_CI_uc_release_can_send_release_note)

    if [[ ${canSendReleaseNote} ]] ; then
        info "send release note"

        execute ${LFS_CI_ROOT}/bin/sendReleaseNote      \
            -r ${workspace}/os/releasenote.txt          \
            -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL} \
            -f ${LFS_CI_CONFIG_FILE}
    else
        warning "sending the release note is disabled in config"
    fi

    return
}

## @fn      _workflowToolCreateRelease()
#  @brief   create the LFS release and LFS os in the workflow tool, upload all required attachments
#  @param   <none>
#  @return  <none>
_workflowToolCreateRelease() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME     \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL \
                       LFS_PROD_RELEASE_PREVIOUS_TAG_NAME

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name from job name"

    local osTagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${osTagName}" "next os tag name"

    local releaseTagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}
    mustHaveValue "${releaseTagName}" "next release tag name"

    info "collect revisions from all sub build jobs"
    sort -u ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt > ${workspace}/revisions.txt

    copyImportantNoteFilesFromSubversionToWorkspace 

    # create the os or uboot release note
    info "new release label is ${releaseTagName} based on ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}"
    _createLfsOsReleaseNote 

    createReleaseInWorkflowTool ${osTagName} ${workspace}/os/os_releasenote.xml
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/os_releasenote.xml
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/releasenote.txt
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/changelog.xml
    uploadToWorkflowTool        ${osTagName} ${workspace}/revisions.txt

    [[ -e ${workspace}/importantNote.txt ]] &&
        uploadToWorkflowTool    ${osTagName} ${workspace}/importantNote.txt

    _copyFileToBldDirectory ${workspace}/os/os_releasenote.xml lfs_os_releasenote.xml
    _copyFileToBldDirectory ${workspace}/os/releasenote.txt    lfs_os_releasenote.txt
    _copyFileToBldDirectory ${workspace}/os/changelog.xml      lfs_os_changelog.xml
    _copyFileToBldDirectory ${workspace}/revisions.txt         revisions.txt 
    _copyFileToBldDirectory ${workspace}/importantNote.txt     importantNote.txt
    _copyFileToBldDirectory ${workspace}/bld/bld-externalComponents-summary/externalComponents externalComponents.txt

    if [[ ${productName} == "LFS" ]] ; then
        _createLfsRelReleaseNoteXml ${releaseTagName} ${workspace}/rel/releasenote.xml
        createReleaseInWorkflowTool ${releaseTagName} ${workspace}/rel/releasenote.xml
        uploadToWorkflowTool        ${releaseTagName} ${workspace}/rel/releasenote.xml

        _copyFileToBldDirectory ${workspace}/rel/releasenote.xml lfs_rel_releasenote.xml
    fi

    return
}

## @fn      _copyFileToBldDirectory()
#  @brief   copy a file into the build directory bld/bld-lfs-release
#  @param   {srcFile}    name / location of the source file
#  @param   {dstFile}    name of the destination file
#  @return  <none>
_copyFileToBldDirectory() {
    local srcFile=${1}
    local dstFile=${2}

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dstPath=${workspace}/bld/bld-lfs-release
    execute mkdir -p ${dstPath}

    [[ -e ${srcFile} ]] && \
        execute cp -f ${srcFile} ${dstPath}/${dstFile}
   
    # return uses the exit code of the last command, if you just write "return"
    return 0
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
#  @param   <none>
#  @return  <none>
_createLfsOsReleaseNote() {

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME \
                       LFS_PROD_RELEASE_PREVIOUS_TAG_NAME \
                       LFS_CI_ROOT LFS_CI_CONFIG_FILE \
                       JOB_NAME BUILD_NUMBER \

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName 

    info "creating release note for ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}"
    
    execute mkdir -p ${workspace}/os
    copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} ${BUILD_NUMBER} changelog.xml
    execute mv ${WORKSPACE}/changelog.xml ${workspace}/os/changelog.xml
    mustExistFile ${workspace}/os/changelog.xml

    # convert the changelog xml to a release note
    execute cd ${workspace}/os/
    execute ln -sf ../bld .
    execute rm -f releasenote.txt releasenote.xml

    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteContent \
            -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}     \
            > releasenote.txt
    rawDebug ${workspace}/os/releasenote.txt

    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML          \
                    -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}  \
                    -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} \
                    -f ${LFS_CI_CONFIG_FILE}                 \
                    -T OS                                    \
                    > releasenote.xml
    rawDebug ${workspace}/os/releasenote.xml

    execute mv -f ${workspace}/os/releasenote.xml ${workspace}/os/os_releasenote.xml

    mustBeValidXmlReleaseNote ${workspace}/os/os_releasenote.xml

    return
}

## @fn      _createLfsRelReleaseNoteXml()
#  @brief   create an PSLFS_REL release note 
#  @param   <none>
#  @return  <none>
_createLfsRelReleaseNoteXml() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    requiredParameters LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL  \
                       LFS_PROD_RELEASE_PREVIOUS_TAG_NAME     \
                       LFS_CI_ROOT LFS_CI_CONFIG_FILE

    info "creating release note xml for ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}"
    execute mkdir -p ${workspace}/rel/bld/bld-externalComponents-summary

    execute cd ${workspace}/rel/
    execute grep sdk ${workspace}/bld/bld-externalComponents-summary/externalComponents > ${workspace}/rel/bld/bld-externalComponents-summary/externalComponents

    echo "PS_LFS_OS <> = ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}" >> ${workspace}/rel/bld/bld-externalComponents-summary/externalComponents

    # no changes here, just a dummy changelog is required
    echo '<log />' > changelog.xml 

    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML                      \
                            -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}  \
                            -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL} \
                            -T OS                                        \
                            -f ${LFS_CI_CONFIG_FILE}                     \
                            > releasenote.xml
    rawDebug ${workspace}/releasenote.xml

    return
}

