#!/bin/bash

## @fn      usecase_LFS_RELEASE_SEND_RELEASE_NOTE()
#  @brief   create a release note and send it to the community
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_SEND_RELEASE_NOTE() {
    # TODO: demx2fk3 2015-08-05 add externalComponents fsmpsl psl fsmci lrcpsl from to artifacts
    mustBePreparedForReleaseTask

    requiredParameters LFS_CI_CONFIG_FILE LFS_CI_ROOT       \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME    \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL

    _workflowToolCreateRelease
    _sendReleaseNote
    _storeArtifactsFromRelease

    return
}

_storeArtifactsFromRelease() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local osTagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${osTagName}" "next os tag name"

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

_sendReleaseNote() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace
    local releaseTagName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}
    mustHaveValue "${releaseTagName}" "next release tag name"
    local canSendReleaseNote=$(getConfig LFS_CI_uc_release_can_send_release_note)
    if [[ ${canSendReleaseNote} ]] ; then
        info "send release note"
        execute ${LFS_CI_ROOT}/bin/sendReleaseNote  -r ${workspace}/os/releasenote.txt \
                                                    -t ${releaseTagName}               \
                                                    -f ${LFS_CI_CONFIG_FILE}
    else
        warning "sending the release note is disabled in config"
    fi
}

_workflowToolCreateRelease() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME     \
                       LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL \
                       LFS_PROD_RELEASE_PREVIOUS_TAG_NAME
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

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

    _copyFileToBldDirectory ${workspace}/os/os_releasenote.xml \
        ${workspace}/bld/bld-lfs-release/lfs_os_releasenote.xml
    _copyFileToBldDirectory ${workspace}/os/releasenote.txt \
        ${workspace}/bld/bld-lfs-release/lfs_os_releasenote.txt
    _copyFileToBldDirectory ${workspace}/os/changelog.xml \
        ${workspace}/bld/bld-lfs-release/lfs_os_changelog.xml
    _copyFileToBldDirectory ${workspace}/revisions.txt \
        ${workspace}/bld/bld-lfs-release/revisions.txt 
    _copyFileToBldDirectory ${workspace}/bld/bld-externalComponents-summary/externalComponents \
        ${workspace}/bld/bld-lfs-release/externalComponents.txt
    _copyFileToBldDirectory ${workspace}/importantNote.txt \
        ${workspace}/bld/bld-lfs-release/importantNote.txt

    if [[ ${productName} == "LFS" ]] ; then
        _createLfsRelReleaseNoteXml ${releaseTagName} ${workspace}/rel/releasenote.xml
        createReleaseInWorkflowTool ${releaseTagName} ${workspace}/rel/releasenote.xml
        uploadToWorkflowTool        ${releaseTagName} ${workspace}/rel/releasenote.xml

        _copyFileToBldDirectory ${workspace}/rel/releasenote.xml ${workspace}/bld/bld-lfs-release/lfs_rel_releasenote.xml
    fi

    return
}

_copyFileToBldDirectory() {
    local srcFile=${1}
    local dstFile=${2}

    mkdir -p $(dirname ${dstFile})
    [[ -e ${srcFile} ]] && \
        execute cp -f ${srcFile} ${dstFile}
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
#  @param   <none>
#  @return  <none>
_createLfsOsReleaseNote() {

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
#  @param   <none>
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


