#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh

## @fn      ci_job_release()
#  @brief   dispatcher for the release jobs
#  @param   <none>
#  @return  <none>
ci_job_release() {

    # requiredParameters TESTED_BUILD_JOBNAME TESTED_BUILD_NUMBER
    requiredParameters JOB_NAME BUILD_NUMBER

    local serverPath=$(getConfig jenkinsMasterServerPath)
    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    local location=$(getLocationName)
    local product=$(getProductNameFromJobName)
    local branch=${locationToSubversionMap["${product}_${location}"]}
    mustHaveBranchName

    info "promoted build is ${TESTED_BUILD_JOBNAME} / ${TESTED_BUILD_NUMBER}"

    # find the related jobs of the build
    mustHaveNextLabelName
    local releaseLabel=$(getNextReleaseLabel)
    local packageJobName=$(getPackageJobNameFromUpstreamProject ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER})
    local packageBuildNumber=$(getPackageBuildNumberFromUpstreamProject ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER})
    local buildJobName=$(getBuildJobNameFromUpstreamProject ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER})
    local buildBuildNumber=$(getBuildBuildNumberFromUpstreamProject ${TESTED_BUILD_JOBNAME} ${TESTED_BUILD_NUMBER})

    local productName=$(getProductNameFromJobName)
    mustHaveValue ${packageJobName}
    mustHaveValue ${packageBuildNumber}
    mustHaveValue ${buildJobName}
    mustHaveValue ${buildBuildNumber}
    mustHaveValue ${releaseLabel}
    mustHaveValue "${productName}" "product name"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${releaseLabel}"

    info "found package job: ${packageJobName} / ${packageBuildNumber}"
    info "found build   job: ${buildJobName} / ${buildBuildNumber}"
    
    local ciBuildShare=$(getConfig LFS_CI_UC_package_internal_link)
    local workspace=${ciBuildShare}/build_${packageBuildNumber}
    mustExistSymlink ${workspace}

    debug "found results of package job on share: ${workspace}"

    local subJob=$(getTargetBoardName)
    mustHaveTargetBoardName

    info "sub task is ${subJob}"
    case ${subJob} in
        upload_to_subversion)
            # from subversion.sh
            uploadToSubversion "${workspace}" "${branch}" "upload of build ${JOB_NAME} / ${BUILD_NUMBER}"
        ;;
        build_results_to_share)
            extractArtifactsOnReleaseShare "${buildJobName}" "${buildBuildNumber}"
        ;;
        create_releasenote_textfile)
            # TODO: demx2fk3 2014-06-05  is this correct?!?!
            createReleaseNoteTextFile "${TESTED_BUILD_JOBNAME}" "${TESTED_BUILD_NUMBER}" "${buildJobName}" "${buildBuildNumber}"
        ;;
        create_release_tag)
            createReleaseTag ${buildJobName} ${buildBuildNumber}
        ;;
        create_source_tag) 
            createTagOnSourceRepository ${buildJobName} ${buildBuildNumber}
        ;;
        summary)
            createReleaseNoteTextFile "${TESTED_BUILD_JOBNAME}" "${TESTED_BUILD_NUMBER}" "${buildJobName}" "${buildBuildNumber}"
        ;;
        *)
            error "subJob not known (${subJob})"
            exit 1
        ;;
    esac

    return
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
    local workspace=$(getWorkspaceName)
    local server=$(getConfig jenkinsMasterServerHostName)
    local resultBuildShare=$(getConfig LFS_PROD_UC_release_copy_build_to_share)
    mustHaveWorkspaceName

    mustHaveNextLabelName
    local labelName=$(getNextReleaseLabel)
    mustHaveValue "${labelName}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"

    cd ${workspace}/bld/
    for dir in bld-*-* ; do
        [[ -d ${dir} ]] || continue
        basename=$(basename ${dir})

        local destination=${resultBuildShare}/${basename}/${labelName}
        info "copy ${basename} to buildresults share ${destination}"

        executeOnMaster mkdir -p ${destination}
        execute rsync -av --exclude=.svn ${workspace}/bld/${basename}/. ${server}:${destination}
    done

    info "clean up workspace"
    execute rm -rf ${workspace}/bld

    return
}

## @fn      createReleaseNoteTextFile()
#  @brief   create a release note in txt format
#  @param   <none>
#  @return  <none>
createReleaseNoteTextFile() {
    local testedJobName=$1
    local testedBuildNumber=$2
    local buildJobName=$3
    local buildBuildNumber=$4

    # get the change log file from master
    local buildDirectory=$(getBuildDirectoryOnMaster ${JOB_NAME} ${BUILD_NUMBER})
    local serverName=$(getConfig jenkinsMasterServerHostName)
    
    # TODO: demx2fk3 2014-06-25 remove the export block and do it in a different way
    export productName=$(getProductNameFromJobName)
    export taskName=$(getTaskNameFromJobName)
    export subTaskName=$(getSubTaskNameFromJobName)
    export location=$(getLocationName)
    export config=$(getTargetBoardName)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    mustHaveCurrentLabelName
    local releaseLabel=${LFS_CI_CURRENT_LABEL_NAME}
    mustHaveValue "${releaseLabel}" "next release label name"

    export LFS_CI_PS_LFS_OS_TAG_NAME=${LFS_CI_CURRENT_LABEL_NAME}
    export LFS_CI_PS_LFS_REL_TAG_NAME=${LFS_CI_CURRENT_LABEL_NAME//PS_LFS_OS_/PS_LFS_REL_}

    info "new release label is ${releaseLabel}"

    execute rsync -ae ssh ${serverName}:${buildDirectory}/changelog.xml ${workspace}

    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}" "externalComponents fsmpsl psl fsmci"

    # convert the changelog xml to a release note
    cd ${workspace}
    execute rm -f releasenote.txt releasenote.xml

    ${LFS_CI_ROOT}/bin/getReleaseNoteContent -t ${releaseLabel} -f ${LFS_CI_ROOT}/etc/file.cfg > releasenote.txt
    mustBeSuccessfull "$?" "getReleaseNoteContent"

    ${LFS_CI_ROOT}/bin/getReleaseNoteXML  -t ${releaseLabel} -f ${LFS_CI_ROOT}/etc/file.cfg > releasenote.xml
    mustBeSuccessfull "$?" "getReleaseNoteXML"

    # check with wft
    info "validating release note"
    local wftApiKey=$(getConfig WORKFLOWTOOL_api_key)
    local wftReleaseNoteValidate=$(getConfig WORKFLOWTOOL_url_releasenote_validation)
    local wftReleaseNoteXsd=$(getConfig WORKFLOWTOOL_url_releasenote_xsd)

    # local check first
    execute rm -f releasenote.xsd
    execute curl -k ${wftReleaseNoteXsd} --output releasenote.xsd
    mustExistFile releasenote.xsd

    execute xmllint --schema releasenote.xsd releasenote.xml

    # remove check with wft next
    execute curl -k ${wftReleaseNoteValidate} \
                 -F access_key=${wftApiKey}   \
                 -F file=@releasenote.xml                      

    # upload to workflow tool
    info "TODO: upload to wft"
    local wftCreateRelease=$(getConfig WORKFLOWTOOL_url_create_release)
    local wftUploadAttachment=$(getConfig WORKFLOWTOOL_url_upload_attachment)

    info "send release note"
    execute ${LFS_CI_ROOT}/bin/sendReleaseNote  -r releasenote.txt             \
                                                -t ${releaseLabel}             \
                                                -f ${LFS_CI_ROOT}/etc/file.cfg

    info "release is done."
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

    local workspace=$(getWorkspaceName)
    local requiredArtifacts=$(getConfig LFS_CI_UC_release_required_artifacts)
    mustHaveWorkspaceWithArtefactsFromUpstreamProjects "${jobName}" "${buildNumber}" "${requiredArtifacts}"

    # get os label
    # no mustHaveNextLabelName, because it's already calculated
    local osLabelName=$(getNextReleaseLabel)
    mustHaveValue "${osLabelName}" "no os label name"

    # get artifacts
    revisionFile=${workspace}/bld/bld-externalComponents-summary/usedRevisions.txt
    cat ${workspace}/bld//bld-externalComponents-*/usedRevisions.txt | sort -u > ${revisionFile}
    rawDebug ${revisionFile}

    # TODO: demx2fk3 2014-06-06 CLEAN UP!!!!
    #
    #       _                                _ 
    #   ___| | ___  __ _ _ __    _   _ _ __ | |
    #  / __| |/ _ \/ _` | '_ \  | | | | '_ \| |
    # | (__| |  __/ (_| | | | | | |_| | |_) |_|
    #  \___|_|\___|\__,_|_| |_|  \__,_| .__/(_)
    #                                 |_|      

    # TODO: demx2fk3 2014-06-06 add check: ensure, that locataions are unque
    mustExistFile ${revisionFile}
    rawDebug ${revisionFile}

    # check for branch
    local svnUrl=$(getConfig LFS_PROD_svn_delivery_os_repos_url)
    local svnUrlOs=${svnUrl}
    local branch=pre_${osLabelName}

    svnUrlOs=$(normalizeSvnUrl ${svnUrlOs})
    svnUrl=$(normalizeSvnUrl ${svnUrl})
    mustHaveValue "${svnUrl}" "svnUrl"
    mustHaveValue "${svnUrlOs}" "svnUrlOs"

    info "using lfs os ${osLabelName}"
    info "using repos ${svnUrlOs}/branches/${branch}"
    info "using repos for new tag ${svnUrlOs}/tags/${osLabelName}"
    info "using repos for package ${svnUrl}/subsystems/"

    if existsInSubversion ${svnUrlOs}/tags ${osLabelName} ; then
        error "tag ${osLabelName} already exists"
        exit 1
    fi

    if existsInSubversion ${svnUrlOs}/branches ${branch} ; then
        info "removing branch ${branch}"
        svnRemove -m removing_branch_for_production ${svnUrlOs}/branches/${branch} 
    fi

    info "creating branch ${branch}"
    svnMkdir -m creating_new_branch_${branch} ${svnUrlOs}/branches/${branch}

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
            src-*)
                svnCopy -m tag_for_package_src_${src} ${svnUrlOs}/branches/${branch} \
                    ${svnUrl}/subsystems/${src}/${osLabelName}
            ;;
            *)
                dirname=$(dirname ${src})
                svnMkdir -m mkdir_for_${src} ${svnUrlOs}/branches/${branch}/${dirname}
            ;;
        esac

        info "copy ${src} to ${branch}"
        svnCopy -r ${rev} -m branching_src_${src}_to_${branch} \
            ${normalizedUrl}                                   \
            ${svnUrlOs}/branches/${branch}/${dirname}

    done < ${revisionFile}

    # check for the branch
    info "svn repos url is ${svnUrl}/branches/${branch}"

    svnCopy -m create_new_tag_${osLabelName} \
        ${svnUrl}/os/branches/${branch}      \
        ${svnUrl}/os/tags/${osLabelName}

    info "branch ${branch} no longer required, removing branch"
    svnRemove -m removing_branch_for_production ${svnUrlOs}/branches/${branch} 

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
    local requiredArtifacts=$(getConfig LFS_CI_UC_release_required_artifacts)
    mustHaveWorkspaceWithArtefactsFromUpstreamProjects "${jobName}" "${buildNumber}" "${requiredArtifacts}"

    # get os label
    # no mustHaveNextLabelName, because it's already calculated
    local osLabelName=$(getNextReleaseLabel)
    local osReleaseLabelName=$(sed "s/_LFS_OS_/_LFS_REL_/" <<< ${osLabelName} )
    mustHaveValue "${osLabelName}" "no os label name"

    # check for branch
    # TODO: demx2fk3 2014-07-08 this is not a nice way to do this, but there
    # is no other way at the moment
    # better: getConfig kayName -t tagName=${osLabelName}
    export tagName=${osLabelName}
    local svnUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url)
    unset tagName

    local branch=$(getBranchName)
    mustHaveBranchName

    # get sdk label
    commonentsFile=${workspace}/bld/bld-externalComponents-summary/externalComponents   
    mustExistFile ${commonentsFile}

    local sdk2=$(getConfig sdk2 ${commonentsFile})
    local sdk3=$(getConfig sdk3 ${commonentsFile})

    info "using sdk2 ${sdk2}"
    info "using sdk3 ${sdk3}"
    info "using lfs os ${osLabelName}"
    info "using lfs rel ${osReleaseLabelName}"

    # check for the branch
    info "svn repos url is ${svnUrl}/branches/${branch}"
    shouldNotExistsInSubversion ${svnUrl}/tags/ "${osReleaseLabelName}"

    if ! existsInSubversion ${svnUrl}/branches ${branch} ; then
        svnMkdir -m creating_branch_for_${branch} ${svnUrl}/branches/${branch} 
    fi

    # update svn:externals
    # TODO: demx2fk3 2014-07-09 fixme do this in a different way - more configurable
    local svnExternalsFile=$(createTempFile)
    echo "^/os/tags/${osLabelName}/os os " >> ${svnExternalsFile}

    if [[ ${sdk3} ]] ; then 
        echo "/isource/svnroot/BTS_D_SC_LFS/sdk/tags/${sdk3} sdk3" >> ${svnExternalsFile}
    fi

    if [[ ${sdk2} ]] ; then 
        echo "/isource/svnroot/BTS_D_SC_LFS/sdk/tags/${sdk2} sdk2" >> ${svnExternalsFile}
    fi

    # commit
    info "updating svn:externals"
    svnCheckout --ignore-externals ${svnUrl}/branches/${branch} ${workspace}/svn

    cd ${workspace}/svn
    svnPropSet svn:externals -F ${svnExternalsFile} .
    svnCommit -m updating_svn:externals_for_${osReleaseLabelName} .

    # make a tag
    info "create tag ${osReleaseLabelName}"
    svnCopy -m create_new_tag ${svnUrl}/branches/${branch} ${svnUrl}/tags/${osReleaseLabelName}

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

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace
    info "workspace is ${workspace}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"

    return
}

## @fn      createProxyReleaseTag()
#  @brief   �brief description�
#  @warning �anything important�
#  @details �full description�
#  @todo    �description of incomplete business�
#  @param   {tagName}    name of the tag
#  @param   {reposName}  name of the svn repos
#  @return  <none>
createProxyReleaseTag() {
    # something like /path/to/release/tag
    # param
    local tagName=$1
    local reposName=$2
    local proxySvnUrl=$(getConfig LFS_PROD_svn_delivery_proxy_repos_url)
    local branchName=proxyBranchForCreateTag
    local externals=$(createTempFile)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    mustExistBranchInSubversion ${proxySvnUrl} ${branchName}

    svnCheckout ${proxySvnUrl}/${branchName} ${workspace}

    svn pg svn:externals ${svnServer}/${releaseTagPath} > ${externals}
    mustBeSuccessfull "$?" "svn pg svn:externals command"
    rawDebug ${externals}

    # example: echo "^/os/tags/${osLabelName}/os os " >> ${svnExternalsFile}
    perl -p -ie "s:\^:/isource/svnroot/${reposName}:" ${externals}

    svn ps svn:externals -F ${externals} ${workspace}
    mustBeSuccessfull "$?" "svn pg svn:externals command"

    svnCommit -m createProxyTagFor${tagName} ${workspace}
    svnCopy ${proxySvnUrl}/${branchName} ${proxySvnUrl}/tags/${tagName}

    return
}
