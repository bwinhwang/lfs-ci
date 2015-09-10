#!/bin/bash
## @file  uc_release.sh
#  @brief usecase release 

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_release}         ]] && source ${LFS_CI_ROOT}/lib/release.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh

source ${LFS_CI_ROOT}/lib/uc_release_create_rel_tag.sh
source ${LFS_CI_ROOT}/lib/uc_release_create_source_tag.sh
source ${LFS_CI_ROOT}/lib/uc_release_prechecks.sh
source ${LFS_CI_ROOT}/lib/uc_release_send_release_note.sh
source ${LFS_CI_ROOT}/lib/uc_release_share_build_artifacts.sh
source ${LFS_CI_ROOT}/lib/uc_release_share_build_artifacts_kernelsource.sh
source ${LFS_CI_ROOT}/lib/uc_release_update_deps.sh
source ${LFS_CI_ROOT}/lib/uc_release_upload_to_svn.sh

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @detail  This is a dispatcher for the jobs in old style.
#           This can be removed, when all jobs are migrated.
#  @param   <none>
#  @return  <none>
ci_job_release() {
    local subJob=$(getSubTaskNameFromJobName)
    mustHaveValue "${subJob}" "subtask name"

    info "task is ${subJob}"
    case ${subJob} in
        build_results_to_share)               usecase_LFS_RELEASE_SHARE_BUILD_ARTIFACTS               ;;
        build_results_to_share_kernelsources) usecase_LFS_RELEASE_SHARE_BUILD_ARTIFACTS_KERNELSOURCES ;;
        create_proxy_release_tag)             warning "disabled due to BI#293"                        ;;
        create_release_tag)                   usecase_LFS_RELEASE_CREATE_RELEASE_TAG                  ;;
        create_source_tag)                    usecase_LFS_RELEASE_CREATE_SOURCE_TAG                   ;;
        pre_release_checks)                   usecase_LFS_RELEASE_PRE_RELEASE_CHECKS                  ;;
        summary)                              usecase_LFS_RELEASE_SEND_RELEASE_NOTE                   ;;
        update_dependency_files)              usecase_LFS_RELEASE_UPDATE_DEPS                         ;;
        upload_to_subversion)                 usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION                ;;
        *)                                    fatal "subJob not known (${subJob})"                    ;;
    esac

    return
}

## @fn      usecase_LFS_RELEASE_PREPARE()
#  @brief   usecase LFS Release Prepare
#  @details this usecase is just doing some preparations, so that the following
#           subjobs can run without any problem
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_PREPARE() {
    mustBePreparedForReleaseTask
    databaseEventReleaseStarted
    createArtifactArchive
    return
}

## @fn      isPatchedRelease()
#  @brief   If /os/doc/patched_build.xml is existing, this release is a 'patched release', i.e. at least one board variant is not idential to the base build.
#  @param   <none>
#  @return  {0 or 1}
isPatchedRelease() {

    mustHaveValue "${releaseDirectory}" "releaseDirectory"
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
    if ! isPatchedRelease ; then
        return
    fi
 
    mustHaveValue "${releaseDirectory}" "releaseDirectory"
    mustHaveWorkspaceName
    mustHaveValue "${releaseLabel}" "release label"
    mustHaveValue "${osTagName}" "osTagName"
 
    local importantNoteXML=${releaseDirectory}/os/doc/patched_build.xml
    #copy all patch related files to workflowtool
    info "Uploading all patch related files to WFT"
    uploadToWorkflowTool ${osTagName}  ${importantNoteXML} 
    for file in $(find ${releaseDirectory}/os/doc/patched_release -maxdepth 1 -type f) ; do
        uploadToWorkflowTool ${osTagName} ${file}
    done
    for dir in $(find ${releaseDirectory}/os/doc/patched_release -mindepth 1 -maxdepth 1 -type d) ; do
        dir=${dir##*/}
        header=${dir%_*}
        for file in $(find ${releaseDirectory}/os/doc/patched_release/${dir} -type f) ; do
            execute mv ${file}  ${releaseDirectory}/os/doc/patched_release/${dir}/${header}_${file##*/}
            uploadToWorkflowTool ${osTagName}  ${releaseDirectory}/os/doc/patched_release/${dir}/${header}_${file##*/}
        done
    done
    
    #TODO Richie Maybe later
    #for-loop       execute cp -f ${workspace}/os/patched_build/xxx  ${workspace}/bld/bld-lfs-release/xxx 
}

## @fn      addImportantNoteFromPatchedBuid()
#  @brief   If existing, extract the <Important Note> part out of /os/doc/patched_build.xml and add to importantNote.txt
#  @param   <none
#  @return  <none>
addImportantNoteFromPatchedBuild() {
    local importantNoteXML=${releaseDirectory}/os/doc/patched_build.xml
    debug "using xsltproc to extract important note from ${importantNoteXML}" 
    extractedText=$(xsltproc                                             \
                    ${LFS_CI_ROOT}/lib/contrib/patchedImportantNote.xslt \
                    ${importantNoteXML})
    debug "extractedText=${extractedText}"

    info "adding important notes from patched_build.xml to importantNotes.txt"
    echo "${extractedText}" >> ${workspace}/importantNote.txt
    debug "Content of ${workspace}/importantNote.txt = "
    debug "`cat ${workspace}/importantNote.txt`"
}

