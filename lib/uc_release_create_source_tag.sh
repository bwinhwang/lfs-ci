#!/bin/bash

[[ -z ${LFS_CI_SOURCE_release} ]] && source ${LFS_CI_ROOT}/lib/release.sh

## @fn      usecase_LFS_RELEASE_CREATE_SOURCE_TAG()
#  @brief   create a tag(s) on source repository 
#  @details create tags in the source repository (os/tags) and subsystems (subsystems/tags)
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_CREATE_SOURCE_TAG() {
    mustBePreparedForReleaseTask

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    _mustHaveLfsSourceSubversionUrl
    _createUsedRevisionsFile
    _prepareSubversion

    local revisionFile=
    for revisionFile in ${workspace}/rev/* ; do
        [[ -e ${revisionFile} ]] || continue
        local target=$(basename ${revisionFile})

        mustExistBranchInSubversion ${svnUrlOs}/branches/${branchName} ${target}

        while read src url rev ; do
            _copySourceDirectoryToBranch ${target} ${src} ${url} ${rev}
        done < ${revisionFile}
    done 

    _createSourceTag
    info "tagging done."
    return
}

## @fn      _copySourceDirectoryToBranch()
#  @brief   copy the source directory to the branch and to the subsystem in svn
#  @param   {target}    name of the target directory (fsmr2,r3,r4)
#  @param   {source}    name of the source directory (src-bos)
#  @param   {url}       url of the source directory in svn
#  @param   {rev}       revision in svn
#  @return  <none>
_copySourceDirectoryToBranch() {
    local target=$1
    mustHaveValue "${target}" "target"

    local src=$2
    mustHaveValue "${src}" "src"

    local url=$3
    mustHaveValue "${url}" "svn url"

    local rev=$4
    mustHaveValue "${rev}" "svn revision"

    local dirname=
    local canCreateSourceTag=$(getConfig LFS_CI_uc_release_can_create_source_tag)
    local normalizedUrl=$(normalizeSvnUrl ${url})
    local tagPrefix=$(getConfig LFS_PROD_uc_release_source_tag_prefix -t target:${target})

    _mustHaveLfsSourceSubversionUrl

    case ${src} in 
        src-*) dirname=${src} ;;
        *)     dirname=$(dirname ${src})
               mustExistBranchInSubversion ${svnUrlOs}/branches/${branchName}/${target} ${dirname} ;;
    esac

    if [[ ${canCreateSourceTag} ]] ; then
        info "copy ${src} to ${branchName}/${target}/${dirname}"
        svnCopy -r ${rev} -F ${commitMessageFile} ${normalizedUrl} \
            ${svnUrlOs}/branches/${branchName}/${target}/${dirname}

        # we have two conditions here: first one: ${src} must start with src-*
        # 2nd condition: it should not exist in subversion.
        # the if looks a little bit strange, but it's legal bash!
        if [[ ${src} =~ src-* ]] && \
           ! existsInSubversion ${svnUrl}/subsystems/${src}/ ${tagPrefix}${osLabelName} ; then

            svnCopy -m ${commitMessageFile} \
                ${svnUrlOs}/branches/${branchName}/${target}/${src} \
                ${svnUrl}/subsystems/${src}/${tagPrefix}${osLabelName}
            trace "CLEANUP svn rm -m cleanup ${svnUrl}/subsystems/${src}/${tagPrefix}${osLabelName}"
        fi
    else
        warning "creating a source tag is disabled in config"
    fi

    return
}

## @fn      _createSourceTag()
#  @brief   create the source tag in BTS_SC_LFS/os/tags/
#  @param   <none>
#  @return  <none>
_createSourceTag() {
    _mustHaveLfsSourceSubversionUrl

    local canCreateSourceTag=$(getConfig LFS_CI_uc_release_can_create_source_tag)
    local branch=pre_${osLabelName}

    if [[ ${canCreateSourceTag} ]] ; then
        svnCopy -F ${commitMessageFile}         \
            ${svnUrl}/os/branches/${branchName} \
            ${svnUrl}/os/tags/${osLabelName}

        info "branch ${branchName} no longer required, removing branch"
        svnRemove -F ${commitMessageFile} ${svnUrlOs}/branches/${branchName} 
    else
        warning "creating a source tag is disabled in config"
    fi
}

## @fn      _createUsedRevisionsFile()
#  @brief   create a file of all used revisions from all sub builds
#  @param   <none>
#  @return  <none>
_createUsedRevisionsFile() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    execute mkdir -p ${workspace}/rev/

    local revisionFile=
    for revisionFile in ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt ; do
        [[ -e ${revisionFile} ]] || continue

        rawDebug "${revisionFile}"

        local dirName=$(basename $(dirname ${revisionFile}))
        local cfg=$(cut -d- -f3 <<< ${dirName})
        local tagDirectory=$(getConfig LFS_PROD_uc_release_source_tag_directory -t cfg:${cfg})
        info "using tag dir ${tagDirectory} for cfg ${cfg}"

        execute -l ${workspace}/rev/${tagDirectory} sort -u ${revisionFile} ${workspace}/rev/${tagDirectory} 
        rawDebug ${workspace}/rev/${tagDirectory}
    done

    return
}

## @fn      _prepareSubversion()
#  @brief   prepare branches and checks, if everything is ready in svn
#  @param   <none>
#  @return  <none>
_prepareSubversion() {
    _mustHaveLfsSourceSubversionUrl

    # check for branch
    if existsInSubversion ${svnUrlOs}/tags ${osLabelName} ; then
        fatal "tag ${osLabelName} already exists"
    fi

    if existsInSubversion ${svnUrlOs}/branches ${branchName} ; then
        info "removing branch ${branchName}"
        svnRemove -F ${commitMessageFile} ${svnUrlOs}/branches/${branchName} 
    fi
    mustExistBranchInSubversion ${svnUrlOs}/branches ${branchName}

    return 0
}

## @fn      _mustHaveLfsSourceSubversionUrl()
#  @brief   ensures, that all required variables are set for the usecase
#  @param   <none>
#  @return  <none>
_mustHaveLfsSourceSubversionUrl() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME

    svnUrl=$(getConfig lfsSourceRepos)
    svnUrl=$(normalizeSvnUrl ${svnUrl})
    svnUrlOs=${svnUrl}/os
    mustHaveValue "${svnUrl}" "svnUrl"
    mustHaveValue "${svnUrlOs}" "svnUrlOs"

    # get os label
    osLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${osLabelName}" "no os label name"

    commitMessageFile=$(createTempFile)
    echo "creating source tag of LFS production ${osLabelName}" > ${commitMessageFile}

    branchName=pre_${osLabelName}

    return
}
