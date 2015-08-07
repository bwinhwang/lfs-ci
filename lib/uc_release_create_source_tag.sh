#!/bin/bash

[[ -z ${LFS_CI_SOURCE_release} ]] && source ${LFS_CI_ROOT}/lib/release.sh

## @fn      usecase_LFS_RELEASE_CREATE_SOURCE_TAG()
#  @brief   create a tag(s) on source repository 
#  @details create tags in the source repository (os/tags) and subsystems (subsystems/tags)
#  @param   {jobName}        a job name
#  @param   {buildNumber}    a build number
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_CREATE_SOURCE_TAG() {
    local jobName=$1
    local buildNumber=$2

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME

    local workspace=$(getWorkspaceName)
    local requiredArtifacts=$(getConfig LFS_CI_UC_release_required_artifacts)
    # mustHaveWorkspaceWithArtefactsFromUpstreamProjects "${jobName}" "${buildNumber}" "externalComponents"

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


