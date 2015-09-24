#!/bin/bash
# @file  uc_release_update_deps.sh
# @brief usecase "release - update dependencies files in svn"

[[ -z ${LFS_CI_SOURCE_release} ]] && source ${LFS_CI_ROOT}/lib/release.sh

## @fn      usecase_LFS_RELEASE_UPDATE_DEPS()
#  @brief   update the dependency files for all components of a build
#  @param   <none>
#  @return  <none>
usecase_LFS_RELEASE_UPDATE_DEPS() {

    mustBePreparedForReleaseTask

    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME \
                       LFS_PROD_RELEASE_PREVIOUS_TAG_NAME

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local componentsFile=$(createTempFile)
    execute -n sort -u ${workspace}/bld/bld-externalComponents-*/usedRevisions.txt > ${componentsFile}

    local releaseLabelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    local oldReleaseLabelName=${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}

    # without the old label name, the Dependencies file will be destroyed
    mustHaveValue "${oldReleaseLabelName}" "old release label name"
    local canCommitDependencies=$(getConfig LFS_CI_uc_release_can_commit_depencencies)

    info "using values: old value: ${oldReleaseLabelName} new value: ${releaseLabelName}"
    while read name url rev ; do
        local dependenciesFile=${workspace}/${name}/Dependencies

        case ${name} in
            src-*) :        ;; # ok
            *)     continue ;; # not ok, skip
        esac

        info "updating Dependencies and Revisions for ${name} "
        debug "from file: ${name} ${url} ${rev}"

        execute rm -rf ${workspace}/${name}
        svnCheckout --depth=immediates --ignore-externals ${url} ${workspace}/${name}

        if [[ ! -e ${dependenciesFile} ]] ; then
            info "file ${dependenciesFile} does not exist"
            continue
        fi
        
        info "update ${name}/Dependencies";
        local buildNameStaticPart=$(getConfig LFS_PROD_uc_release_update_deps_build_name_part)
        mustHaveValue "${buildNameStaticPart}" "build name static part/LFS_PROD_uc_release_update_deps_build_name_part"
        execute perl -p -i -e "s/\b${buildNameStaticPart}\S+\b/${releaseLabelName}/g" ${dependenciesFile}
        svnDiff ${dependenciesFile}

        if [[ ${canCommitDependencies} ]] ; then 
            info "commiting ${name}/Dependencies"
            local logMessage=${workspace}/commitMessage
            local svnCommitMessage=$(getConfig LFS_PROD_uc_release_svn_message_template \
                                        -t releaseName:${releaseLabelName}              \
                                        -t oldReleaseName:${oldReleaseLabelName}        \
                                        -t revision:${rev})

            echo ${svnCommitMessage} > ${logMessage}
            svnCommit -F ${logMessage} ${dependenciesFile}
        else
            warning "committing of dependencies is disabled in config"
        fi
    done < ${componentsFile}

    info "update done."

    return 0
}

