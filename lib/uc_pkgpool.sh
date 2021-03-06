#!/bin/bash
## @file    uc_pkgpool.sh
#  @brief   build and release a pkgpool release
#  @details The usecase will build and release a pkgpool release.
#            
#           * creation of workspace is done by jenkins git plugin
# 
# jenkins job names: 
#    - PKGPOOL_CI_-_trunk_-_Build
#    - PKGPOOL_CI_-_trunk_-_Test
#    - PKGPOOL_PROD_-_trunk_-_Release
#    - PKGPOOL_PROD_-_trunk_-_Update_Dependencies
#
# Fingerprint file: workspace/bld/bld-pkgpool-release/label
#

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_workflowtool}    ]] && source ${LFS_CI_ROOT}/lib/workflowtool.sh
[[ -z ${LFS_CI_SOURCE_jenkins}         ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_subversion}      ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_git}             ]] && source ${LFS_CI_ROOT}/lib/git.sh
[[ -z ${LFS_CI_SOURCE_try}             ]] && source ${LFS_CI_ROOT}/lib/try.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

## @fn      usecase_PKGPOOL_BUILD()
#  @brief   run the usecase PKGPOOL_BUILD
#  @param   <none>
#  @return  <none>
usecase_PKGPOOL_BUILD() {
    requiredParameters WORKSPACE

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    local buildParameters="$(getConfig PKGPOOL_additional_build_parameters)"
    # build parameters could be empty => no mustHaveValue
    # mustHaveValue "${buildParameters}" "additional build parameters"

    # git clone, created by jenkins git plugin
    local gitWorkspace=${WORKSPACE}/src
    mustExistDirectory ${gitWorkspace}

    _preparePkgpoolWorkspace

    info "building pkgpool..."
    local buildLogFile=$(createTempFile)
    cd ${workspace}
    execute -l ${buildLogFile} ${gitWorkspace}/build ${buildParameters} 

    # put build log for later analysis into the artifacts
    execute mkdir -p ${workspace}/bld/bld-pkgpool-release/
    execute cp ${buildLogFile}      ${workspace}/bld/bld-pkgpool-release/build.log
    execute cp -a ${workspace}/logs ${workspace}/bld/bld-pkgpool-release/

    _tagPkgpool ${buildLogFile}
    createArtifactArchive

    return 0
}

## @fn      _preparePkgpoolWorkspace()
#  @brief   prepare the pkgpool workspace
#  @param   <none>
#  @return  <none>
_preparePkgpoolWorkspace() {
    requiredParameters WORKSPACE

    info "preparing git workspace..."
    local gitWorkspace=${WORKSPACE}/src
    mustExistDirectory ${gitWorkspace}
    cd ${gitWorkspace}

    local cleanWorkspace=$(getConfig PKGPOOL_CI_uc_build_can_clean_workspace)
    if [[ ${cleanWorkspace} ]] ; then
        execute rm -rf ${gitWorkspace}/src
        gitReset --hard
    fi

    execute ./bootstrap

    # checking for changed files.
    local directory=
    for directory in $(gitStatus -s | cut -c3-) ; do
        debug "updating ${directory}"
        gitSubmodule update ${directory}
    done

    # ensure, that everything is clean. If it is not clean, git status will show some output and
    # we will ensure, that it is clean again by removing everything in .../src and check it out / bootstrep it 
    # again.
    # git status does not return a non-zero exit code in case that there are untracked / unchecked-in files.
    # but git status will output nothing, if everything is clean and fine.
    if [[ "$(gitStatus -s)" ]] ; then
        warning "the git workspace is not clean after update. We will fallback to the clean way."
        info "resetting workspace and bootstrap clean build environment..."
        execute rm -rf ${gitWorkspace}/src
        gitReset --hard
        execute ./bootstrap
    fi

    return 0
}

## @fn      _tagPkgpool()
#  @brief   create the tag of the pkgpool in git
#  @param   {builgLogFile}    name of the build log file
#  @return  <none>
_tagPkgpool() {
    local buildLogFile=$1
    mustExistFile ${buildLogFile}

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    requiredParameters JOB_NAME BUILD_NUMBER WORKSPACE

    local gitWorkspace=${WORKSPACE}/src

    # in case of build from scratch (own jenkins job), we do not have a release tag.
    # => no release
    local canCreateReleaseTag=$(getConfig PKGPOOL_CI_uc_build_can_create_tag_in_git)
    if [[ ${canCreateReleaseTag} ]] ; then
        local releaseTag="$(execute -n sed -ne 's,^\(\[[0-9 :-]*\] \)\?release \([^ ]*\) complete,\2,p' ${buildLogFile})"
        mustHaveValue "${releaseTag}" "release tag"

        info "new pkgpool release tag is ${releaseTag}"

        cd ${gitWorkspace}
        local oldReleaseTag=$(gitDescribe --abbrev=0)
        gitTagAndPushToOrigin ${releaseTag}

        local gitRevision=$(gitRevParse HEAD)

        setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${releaseTag}"

        echo ${oldReleaseTag} > ${workspace}/bld/bld-pkgpool-release/oldLabel
        echo ${releaseTag}    > ${workspace}/bld/bld-pkgpool-release/label
        echo ${gitRevision}   > ${workspace}/bld/bld-pkgpool-release/gitrevision

        execute -n sed -ne 's|^src [^ ]* \(.*\)$|PS_LFS_PKG = \1|p' ${workspace}/pool/*.meta |\
            sort -u > ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt

        rawDebug ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt
    fi

    return 0
}


## @fn      usecase_PKGPOOL_TEST()
#  @brief   run the usecase PKGPOOL_TEST
#  @param   <none>
#  @return  <none>
usecase_PKGPOOL_TEST() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    copyArtifactsToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "pkgpool"
    createArtifactArchive

    return 0
}

## @fn      usecase_PKGPOOL_RELEASE()
#  @brief   run the usecase PKGPOOL_RELEASE
#  @param   <none>
#  @return  <none>
usecase_PKGPOOL_RELEASE() {
    requiredParameters LFS_CI_ROOT UPSTREAM_PROJECT UPSTREAM_BUILD \
                       JOB_NAME BUILD_NUMBER \
                       LFS_CI_CONFIG_FILE

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    # branchName and product name is needed in sendReleaseNote
    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"
    local branchName=$(getBranchName)
    mustHaveValue "${branchName}" "branchName"

    copyArtifactsToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "pkgpool"
    local lastSuccessfulBuildDirectory=$(getBuildDirectoryOnMaster ${JOB_NAME} lastSuccessfulBuild)
    if runOnMaster test -e ${lastSuccessfulBuildDirectory}/forReleaseNote.txt ; then
        info "using old forReleaseNote.txt"
        copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} lastSuccessfulBuild forReleaseNote.txt
        execute mv ${WORKSPACE}/forReleaseNote.txt ${workspace}/forReleaseNote.txt.old

        copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} lastSuccessfulBuild gitrevision
        execute mv ${WORKSPACE}/gitrevision ${workspace}/gitrevision.old
    else
        info "touch forReleaseNote.txt"
        execute touch ${workspace}/forReleaseNote.txt.old
        execute touch ${workspace}/gitrevision.old
    fi

    local label=$(cat ${workspace}/bld/bld-pkgpool-release/label)
    mustHaveValue "${label}" "label"

    local gitRevision=$(cat ${workspace}/bld/bld-pkgpool-release/gitrevision)
    mustHaveValue "${gitRevision}" "gitRevision"

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

    local oldLabel=$(cat ${workspace}/bld/bld-pkgpool-release/oldLabel)
    mustHaveValue "${oldLabel}" "old label"

    echo "<log/>" > ${workspace}/changelog.xml
    cd ${workspace}
    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML \
                -t ${label}                         \
                -o ${oldLabel}                      \
                -T OS                               \
                -P PKGPOOL                          \
                -L $(getLocationName)               \
                -f ${LFS_CI_CONFIG_FILE} > ${workspace}/releasenote.xml
    
    rawDebug ${workspace}/releasenote.xml

    mustBeValidXmlReleaseNote ${workspace}/releasenote.xml

    local releaseNoteTxt=${workspace}/releasenote.txt
    execute touch ${releaseNoteTxt}

    execute sed -i -e "s/PS_LFS_PKG = //g" ${workspace}/forReleaseNote.txt.old
    execute sed -i -e "s/PS_LFS_PKG = //g" ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt
    execute -i -l ${releaseNoteTxt} diff -y -W72 -t --suppress-common-lines \
        ${workspace}/forReleaseNote.txt.old \
        ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt

    rawDebug ${releaseNoteTxt}

    local canCreateReleaseinWft=$(getConfig LFS_CI_uc_release_can_create_release_in_wft)
    if [[ ${canCreateReleaseinWft} ]] ; then
        createReleaseInWorkflowTool ${label} ${workspace}/releasenote.xml
        uploadToWorkflowTool        ${label} ${workspace}/releasenote.xml
    else
        warning "creating release not in WFT is disabled via config"
    fi

    local canSendReleaseNote=$(getConfig LFS_CI_uc_release_can_send_release_note)
    if [[ ${canSendReleaseNote} ]] ; then
        if [[ -s ${releaseNoteTxt} ]] ; then
            execute ${LFS_CI_ROOT}/bin/sendReleaseNote  -r ${releaseNoteTxt}     \
                                                        -t ${label}              \
                                                        -f ${LFS_CI_CONFIG_FILE} \
                                                        -L ${branchName}         \
                                                        -T OS -P PKGPOOL
        fi                                                            
    else
        warning "sending release note is disabled via config"
    fi

    copyFileToArtifactDirectory ${workspace}/releasenote.xml
    copyFileToArtifactDirectory ${workspace}/releasenote.txt
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt

    echo ${gitRevision} > ${workspace}/gitrevision
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${workspace}/gitrevision

    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}

    return 0
}

## @fn      usecase_PKGPOOL_UPDATE_DEPS()
#  @brief   run the usecase PKGPOOL_UPDATE_DEPS
#  @param   <none>
#  @return  <none>
usecase_PKGPOOL_UPDATE_DEPS() {
    requiredParameters LFS_CI_ROOT UPSTREAM_PROJECT UPSTREAM_BUILD

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    copyArtifactsToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "pkgpool"

    local label=$(cat ${workspace}/bld/bld-pkgpool-release/label)
    mustHaveValue "${label}" "label"

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

    local oldLabel=$(cat ${workspace}/bld/bld-pkgpool-release/oldLabel)
    mustHaveValue "${oldLabel}" "old label"

    local newGitRevision=$(cat ${workspace}/bld/bld-pkgpool-release/gitrevision)
    mustHaveValue "${newGitRevision}" "new git revision"

    info "new label is ${label}/${newGitRevision} based on ${oldLabel}"

    execute rm -rfv ${WORKSPACE}/src
    local gitUpstreamRepos=$(getConfig PKGPOOL_git_repos_url)
    mustHaveValue "${gitUpstreamRepos}" "git upstream repos url"
    gitClone ${gitUpstreamRepos} ${WORKSPACE}/src

    local svnUrlsToUpdate=$(getConfig PKGPOOL_PROD_update_dependencies_svn_url)
    mustHaveValue "${svnUrlsToUpdate}" "svn urls for pkgpool"

    local urlToUpdate=""
    for urlToUpdate in ${svnUrlsToUpdate} ; do
        info "url to update ${urlToUpdate}"

        local releaseFile=${workspace}/$(basename ${urlToUpdate})
        local svnUrl=$(dirname ${urlToUpdate})

        local workspace=$(getWorkspaceName)
        mustHaveWorkspaceName
        mustHaveCleanWorkspace

        svnCheckout ${svnUrl} ${workspace}

        local gitLog=${WORKSPACE}/workspace/gitLog.txt
        cd ${WORKSPACE}/src
        local oldGitRevision=$(cat ${workspace}/src/gitrevision)
        mustHaveValue "${oldGitRevision}" "old git revision"
        info "old git revision in $(basename ${svnUrl}) is ${oldGitRevision}"

        if [[ ${oldGitRevision} = ${newGitRevision} ]] ; then
            echo "no change" > ${gitLog}
        else
            gitLog  --format=medium ${oldGitRevision}..${newGitRevision} | \
                sed -e 's,^    %,%,' > ${gitLog}
        fi
        rawDebug ${gitLog}

        cd ${workspace}
        execute sed -i -e "
            s|^PKGLABEL *?=.*|PKGLABEL ?= ${label}|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= ${label}|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool ${label}|
        " ${releaseFile}

        echo ${newGitRevision} > ${workspace}/src/gitrevision

        export LFS_CI_LAST_EXECUTE_LOGFILE=$(createTempFile)
        export LANG=en_US.UTF-8
        try
        (
            info "commiting changes in ${releaseFile} ${workspace}/src/gitrevision"
            svnCommit -F ${gitLog} ${releaseFile} ${workspace}/src/gitrevision
        )
        catch ||
        (
            warning "first svn commit failed, try to correct from error log"

            # logfile from the last execution command (in svnCommit)
            errorLogFile=$(lastExecuteLogFile)
            # LFS_CI_LAST_EXECUTE_LOGFILE is the same file all the time,
            # if we do not unset the variable LFS_CI_LAST_EXECUTE_LOGFILE,
            # the error logfile will be overwritten by the setBuildResultUnstable
            unset LFS_CI_LAST_EXECUTE_LOGFILE
            mustExistFile ${errorLogFile}

            debug "error log file ${errorLogFile}"
            rawDebug ${errorLogFile}

            setBuildResultUnstable

            local errorLineNumber=$(sed -ne 's,^Error in line \([0-9]\+\) : .*,\1,p' ${errorLogFile})
            info "error line numbers: ${errorLineNumber}"
            if [[ -z "${errorLineNumber}" ]] ; then
                error "SVN rejected our commit message for a reason we didn't understand. (see logfile)"
                exit 0
            fi

            for lineNumber in ${errorLineNumber} ; do
                execute sed -i -e "${lineNumber}{s,%,o/o,g;s,^,SVN REJECTED: ,}" ${gitLog}
            done

            warning "SVN rejected some of your commit notes for the release note."
            warning "If you need them in the release note please do another commit"
            warning "with corrected syntax."
            warning "We try to commit with corrected notes."
            rawDebug ${gitLog}

            info "retry commit with corrected commit message..."
            svnCommit -F ${gitLog} ${releaseFile} ${workspace}/src/gitrevision
        ) || exit 1 # when catch part also fails, we exit the usecase

        info "update done for ${urlToUpdate}"
    done

    return 0
}

## @fn      usecase_PKGPOOL_CHECK_FOR_FAILED_VTC()
#  @brief   check, if there are files in the addon arm-cortexa15-linux-gnueabihf-vtc.tar.gz in pkgpool
#  @details vtc is a addon from Transport, which is build within the pkgpool. Current state (2015-08-01) is,
#           that this addon is experimantal and should not be blocking.
#           This usecase was requested by "Sapalski, Samuel (Nokia - DE/Ulm)" <samuel.sapalski@nokia.com>.
#           See also BI #462
#  @param   <none>
#  @return  <none>
usecase_PKGPOOL_CHECK_FOR_FAILED_VTC() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    # --no-build-description will not copy artifacts from the upstream build...
    mustHavePreparedWorkspace --no-build-description
    # so we have to do this by our own...
    copyAndExtractBuildArtifactsFromProject "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "pkgpool"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local logfile=${workspace}/bld/bld-pkgpool-release/logs/arm-cortexa15-linux-gnueabihf-vtc.log.gz
    info "checking for ${logfile}"

    if [[ -e ${logfile} ]] ; then
        if execute -i zgrep -s "LVTC FSMR4 BUILD FAILED" ${logfile} ; then
            execute -i -n zcat ${logfile}
            fatal "VTC build failed."
        fi
    fi

    info "vtc build is ok."
        
    return 0
}
