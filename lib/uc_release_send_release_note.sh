#!/bin/bash
# @file  uc_release_send_release_note.sh
# @brief usecase "release - send release note and create release in WFT"

[[ -z ${LFS_CI_SOURCE_release}      ]] && source ${LFS_CI_ROOT}/lib/release.sh
[[ -z ${LFS_CI_SOURCE_workflowtool} ]] && source ${LFS_CI_ROOT}/lib/workflowtool.sh
[[ -z ${LFS_CI_SOURCE_database}     ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      usecase_LFS_RELEASE_SEND_RELEASE_NOTE()
#  @brief   create a release note and send it to the community
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_SEND_RELEASE_NOTE() {
    mustBePreparedForReleaseTask

    exit_add _releaseDatabaseEventReleaseFailedOrFinished

    _workflowToolCreateRelease
    _sendReleaseNote
    _storeArtifactsFromRelease
    createArtifactArchive

    info "release is done."

    return 0
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

    return 0
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
            -f ${LFS_CI_CONFIG_FILE}                    \
            -T OS                                       \
            -P $(getProductNameFromJobName)             \
            -L $(getLocationName)
    else
        warning "sending the release note is disabled in config"
    fi

    return 0
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

    local state=
    if isPatchedRelease ; then
        state="release_with_restrictions"
        addImportantNoteFromPatchedBuild
    fi

    # create the os or uboot release note
    info "new release label is ${releaseTagName} based on ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}"
    _createLfsOsReleaseNote 

    createReleaseInWorkflowTool ${osTagName} ${workspace}/os/os_releasenote.xml ${state}
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/os_releasenote.xml
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/releasenote.txt
    uploadToWorkflowTool        ${osTagName} ${workspace}/os/changelog.xml
    uploadToWorkflowTool        ${osTagName} ${workspace}/revisions.txt

    [[ -e ${workspace}/importantNote.txt ]] &&
        uploadToWorkflowTool    ${osTagName} ${workspace}/importantNote.txt

    # In case of a patched release perform some specific actions
    handlePatchedRelease

    _copyFileToBldDirectory ${workspace}/os/os_releasenote.xml lfs_os_releasenote.xml
    _copyFileToBldDirectory ${workspace}/os/releasenote.txt    lfs_os_releasenote.txt
    _copyFileToBldDirectory ${workspace}/os/changelog.xml      lfs_os_changelog.xml
    _copyFileToBldDirectory ${workspace}/revisions.txt         revisions.txt 
    _copyFileToBldDirectory ${workspace}/importantNote.txt     importantNote.txt
    _copyFileToBldDirectory ${workspace}/bld/bld-externalComponents-summary/externalComponents externalComponents.txt

    if [[ ${productName} == "LFS" ]] ; then
        _createLfsRelReleaseNoteXml 
        createReleaseInWorkflowTool ${releaseTagName} ${workspace}/rel/releasenote.xml ${state}
        uploadToWorkflowTool        ${releaseTagName} ${workspace}/rel/releasenote.xml

        _copyFileToBldDirectory ${workspace}/rel/releasenote.xml lfs_rel_releasenote.xml
    fi

    return 0
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

    return 0
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
            > ${workspace}/os/releasenote.txt
    rawDebug ${workspace}/os/releasenote.txt

    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML          \
                    -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME}  \
                    -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME} \
                    -f ${LFS_CI_CONFIG_FILE}                 \
                    -T OS                                    \
                    -P $(getProductNameFromJobName)          \
                    -L $(getLocationName)                    \
                    > ${workspace}/os/os_releasenote.xml
    rawDebug ${workspace}/os/os_releasenote.xml
    mustBeValidXmlReleaseNote ${workspace}/os/os_releasenote.xml

    return 0
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

    # TODO: demx2fk3 2015-09-17 use absolut path names
    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML                      \
                            -t ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}  \
                            -o ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL} \
                            -T OS                                        \
                            -P LFS                                       \
                            -f ${LFS_CI_CONFIG_FILE}                     \
                            -L $(getLocationName)                        \
                            > releasenote.xml
    rawDebug ${workspace}/releasenote.xml

    return 0
}

## @fn      isPatchedRelease()
#  @brief   If /os/doc/patched_build.xml is existing, this release is a 'patched release', i.e. at least one board variant is not idential to the base build.
#  @param   <none>
#  @return  {0 or 1}
isPatchedRelease() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME

    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustExistDirectory ${releaseDirectory}

    local importantNoteXML=${releaseDirectory}/os/doc/patched_build.xml
    if [[ -f ${importantNoteXML} ]] ; then
      return 0 
    fi

    return 1
}

## @fn      handlePatchedRelease()
#  @brief   If /os/doc/patched_build.xml is existing, this release is a 'patched release', i.e. at least one board variant is not idential to the base build.
#           In that case we need to add specific files and descrition to the release note
#  @param   <none>
#  @return  <none>
handlePatchedRelease() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME

    # early exist, do nothing, if it is not patched.
    isPatchedRelease || return
 
    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustExistDirectory ${releaseDirectory}

    local osTagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${osTagName}" "osTagName"
 
    local importantNoteXML=${releaseDirectory}/os/doc/patched_build.xml

    # copy all patch related files to workflowtool
    info "Uploading all patch related files to WFT"
    uploadToWorkflowTool ${osTagName}  ${importantNoteXML} 

    local file=
    for file in $(execute -n find ${releaseDirectory}/os/doc/patched_release -maxdepth 1 -type f) ; do
        uploadToWorkflowTool ${osTagName} ${file}
    done
    
    local dir=
    for dir in $(execute -n find ${releaseDirectory}/os/doc/patched_release -mindepth 1 -maxdepth 1 -type d) ; do
        dir=${dir##*/}
        local header=${dir%_*}
        local file=
        for file in $(execute -n find ${releaseDirectory}/os/doc/patched_release/${dir} -type f) ; do
            execute mv ${file} ${releaseDirectory}/os/doc/patched_release/${dir}/${header}_${file##*/}
            uploadToWorkflowTool ${osTagName}  ${releaseDirectory}/os/doc/patched_release/${dir}/${header}_${file##*/}
        done
    done
    
    #TODO Richie Maybe later
    #for-loop       execute cp -f ${workspace}/os/patched_build/xxx  ${workspace}/bld/bld-lfs-release/xxx 
    return 0;
}

## @fn      addImportantNoteFromPatchedBuild()
#  @brief   If existing, extract the <Important Note> part out of /os/doc/patched_build.xml and add to importantNote.txt
#  @param   <none
#  @return  <none>
addImportantNoteFromPatchedBuild() {
    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustExistDirectory ${releaseDirectory}

    local importantNoteXML=${releaseDirectory}/os/doc/patched_build.xml
    debug "using xsltproc to extract important note from ${importantNoteXML}" 
    extractedText=$(xsltproc                                             \
                    ${LFS_CI_ROOT}/lib/contrib/patchedImportantNote.xslt \
                    ${importantNoteXML})
    debug "extractedText=${extractedText}"

    info "adding important notes from patched_build.xml to importantNotes.txt"

    echo "${extractedText}" >> ${workspace}/importantNote.txt
    debug "Content of ${workspace}/importantNote.txt = "
    rawDebug ${workspace}/importantNote.txt

    return 0
}

