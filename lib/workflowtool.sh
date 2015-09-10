#!/bin/bash
## @file  workflowtool.sh
#  @brief common functions for workflowtool 

LFS_CI_SOURCE_workflowtool='$Id$'

## @fn      createReleaseInWorkflowTool()
#  @brief   creates a release in the workflow tool based on a tagName and 
#           the xml release note
#  @param   {tagName}    name of the tag
#  @param   {fileName}   name of the xml release note
#  @param   {restricted} optional / if set, this release will be marked as 'released with restriction'
#  @return  <none>
createReleaseInWorkflowTool() {
    local tagName=$1
    local fileName=$2
    local state=$3

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
    if existsBaselineInWorkflowTool ${tagName} ; then
        update="-F update=yes"  # does exist
    else
        update="-F update=no" # does not exist 
    fi

    #check, if this shall be a restricted release
    local restricted=""
    if [[ ${state} == "release_with_restrictions" ]] ; then
        restricted="-F state_machine=external -F state=released_with_restrictions"
    fi

    info "creating release based on ${fileName} in wft"
    execute ${curl} ${update} ${restricted} -F file=@${fileName}
    echo "${curl} ${update} ${restricted} -F file=@${fileName}" >> ${workspace}/redo.sh

    if ! existsBaselineInWorkflowTool ${tagName} ; then
        error "just created baseline ${tagName} does not exist in WFT"
        exit 1
    fi

    return
}
## @fn      uploadToWorkflowTool()
#  @brief   uploads a file as attachment to a release in workflow tool
#  @param   {tagName}    name of the release
#  @param   {fileName}   name of the xml release note
#  @return  <none>
uploadToWorkflowTool() {
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
    if existsBaselineInWorkflowTool ${tagName} ; then
        update="-F update=yes"  # does exist
    else
        update="-F update=no" # does not exist 
    fi

    info "uploading ${fileName} to wft"
    execute ${curl} ${update} -F file=@${fileName}
    echo "${curl} ${update} -F file=@${fileName}" >> ${workspace}/redo.sh

    return
}

## @fn      existsBaselineInWorkflowTool()
#  @brief   checks, if the given release / tagName exists in the workflowtool
#  @param   {tagName}    name of the release
#  @return  0 if release existss in WFT, 1 otherwise
existsBaselineInWorkflowTool() {
    local tagName=$1

    local wftApiKey=$(getConfig WORKFLOWTOOL_api_key)
    local wftBuildContent=$(getConfig WORKFLOWTOOL_url_build_content)
    # TODO: vm048635 2015-08-12 check why this curl statement is not used
    local curl="curl -k ${wftUploadAttachment}/${tagName} -F access_key=${wftApiKey} "

    # check, if wft already knows about the release
    curl -sf -k ${wftBuildContent}/${tagName} >/dev/null 
    case $? in 
        # reverse logic due to exit code logic: 1 == failure, 0 == ok
        0)  return 0 ;; # does exist
        22) return 1 ;; # does not exist 
        *)  fatal "unknown error from curl $?" ;;
    esac

    # not reachable
    fatal "this part of the code is not reachable. something went VERY wrong!"
}

## @fn      mustBeValidXmlReleaseNote()
#  @brief   validates a xml release note via xsd and workflowtool
#  @param   {fileName}    name of the xml release note
#  @return  raise an error, if xml release note is not valid
mustBeValidXmlReleaseNote() {
    local releaseNoteXml=$1

    # check with wft
    info "validating release note"
    local wftApiKey=$(getConfig WORKFLOWTOOL_api_key)
    local wftReleaseNoteValidate=$(getConfig WORKFLOWTOOL_url_releasenote_validation)
    local wftReleaseNoteXsd=$(getConfig WORKFLOWTOOL_url_releasenote_xsd)

    if [[ ! ${canCreateReleaseInWorkflowTool} ]] ; then
        warning "validating release note xml in WFT is disabled via config"
        return
    fi

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
        fatal "release note xml ${releaseNoteXml} is not valid"
    else 
        info "xml release note is valid"
    fi
        
    return 
}

