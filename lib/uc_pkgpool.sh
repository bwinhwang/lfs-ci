#!/bin/bash

## @file    uc_pkgpool.sh
#  @brief   build and release a pkgpool release
#  @details The usecase will build and release a pkgpool release.
#            
#           * creation of workspace is done by jenkins git plugin
# 
# jenkins job names: PKGPOOL_CI_-_trunk_-_Build
#                    PKGPOOL_CI_-_trunk_-_Test
#                    PKGPOOL_PROD_-_trunk_-_Release
#                    PKGPOOL_PROD_-_trunk_-_Update_Dependencies
#
# Fingerprint file: workspace/bld/bld-pkgpool-release/label
#

[[ -z ${LFS_CI_SOURCE_artifacts}    ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_workflowtool} ]] && source ${LFS_CI_ROOT}/lib/workflowtool.sh
[[ -z ${LFS_CI_SOURCE_jenkins}      ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_subversion}   ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_git}          ]] && source ${LFS_CI_ROOT}/lib/git.sh
[[ -z ${LFS_CI_SOURCE_try}          ]] && source ${LFS_CI_ROOT}/lib/try.sh

## @fn      usecase_PKGPOOL_BUILD()
#  @brief   run the usecase PKGPOOL_BUILD
#  @param   <none>
#  @return  <none>
usecase_PKGPOOL_BUILD() {
    requiredParameters WORKSPACE

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    local releasePrefix=$(getConfig PKGPOOL_PROD_release_prefix)
    mustHaveValue "${releasePrefix}" "pkgpool release prefix"

    local buildLogFile=$(createTempFile)
    local gitWorkspace=${WORKSPACE}/src

    # git clone, created by jenkins git plugin
    mustExistDirectory ${gitWorkspace}

    cd ${gitWorkspace}
    execute rm -rf ${gitWorkspace}/src
    gitReset --hard

    execute ./bootstrap
    cd ${workspace}

    # TODO: demx2fk3 2015-02-09 use different path for testing ci jobs
    execute -n ${gitWorkspace}/build -j24 --prepopulate --release="${releasePrefix}" > ${buildLogFile}
    rawDebug ${buildLogFile}

    local releaseString="$(execute -n sed -ne 's,^release \([^ ]*\) complete$,\1,p' ${buildLogFile})"
    mustHaveValue "${releaseString}" "release string"

    cd ${gitWorkspace}
    local oldRelease=$(gitDescribe --abbrev=0)
    gitTagAndPushToOrigin

    info "new pkgpool release tag: ${releaseString}"
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${releaseString}"

    # required to start the sync 
    execute touch /build/home/SC_LFS/pkgpool/.hashpool

    mkdir -p ${workspace}/bld/bld-pkgpool-release/
    echo ${oldRelease}    > ${workspace}/bld/bld-pkgpool-release/oldLabel
    echo ${releaseString} > ${workspace}/bld/bld-pkgpool-release/label
    execute sed -ne 's|^src [^ ]* \(.*\)$|PS_LFS_PKG = \1|p' ${workspace}/pool/*.meta \
        > ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt

    rawDebug ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt

    return
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
    return
}

## @fn      usecase_PKGPOOL_RELEASE()
#  @brief   run the usecase PKGPOOL_RELEASE
#  @param   <none>
#  @return  <none>
usecase_PKGPOOL_RELEASE() {
    requiredParameters LFS_CI_ROOT UPSTREAM_PROJECT UPSTREAM_BUILD \
                       JOB_NAME BUILD_NUMBER

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    copyArtifactsToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "pkgpool"

    local label=$(cat ${workspace}/bld/bld-pkgpool-release/label)
    mustHaveValue "${label}" "label"

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

    local oldLabel=$(cat ${workspace}/bld/bld-pkgpool-release/oldLabel)
    mustHaveValue "${oldLabel}" "old label"

    # TODO: demx2fk3 2015-02-05 baselines list missing
    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML \
                -t ${label}                         \
                -o ${oldLabel}                      \
                -f ${LFS_CI_ROOT}/etc/file.cfg > ${workspace}/releasenote.xml
    
    rawDebug ${workspace}/releasenote.xml

    mustBeValidXmlReleaseNote ${workspace}/releasenote.xml

    createReleaseInWorkflowTool ${label} ${workspace}/releasenote.xml
    uploadToWorkflowTool        ${label} ${workspace}/releasenote.xml

    copyFileToArtifactDirectory releasenote.xml

    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}

    return
}

## @fn      usecase_PKGPOOL_UDPATE_DEPS()
#  @brief   run the usecase PKGPOOL_UPDATE_DEPS
#  @param   <none>
#  @return  <none>
usecase_PKGPOOL_UDPATE_DEPS() {
    requiredParameters LFS_CI_ROOT UPSTREAM_PROJECT UPSTREAM_BUILD

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    local gitWorkspace=${WORKSPACE}/src
    mustExistDirectory ${gitWorkspace}

    copyArtifactsToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "pkgpool"

    local label=$(cat ${workspace}/bld/bld-pkgpool-release/label)
    mustHaveValue "${label}" "label"

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

    local oldLabel=$(cat ${workspace}/bld/bld-pkgpool-release/oldLabel)
    mustHaveValue "${oldLabel}" "old label"

    local svnUrlsToUpdate=$(getConfig PKGPOOL_PROD_uc_update_dependencies_svn_urls)
    mustHaveValue "${svnUrlsToUpdate}" "svn urls for pkgpool"

    local urlToUpdate=""

    for urlToUpdate in ${svnUrlsToUpdate} ; do
        info "url to update ${urlToUpdate}"

        local releaseFile=$(basename ${urlToUpdate})
        local svnUrl=$(dirname ${urlToUpdate})

        local workspace=$(getWorkspaceName)
        mustHaveWorkspaceName

        svnCheckout ${svnUrl} ${workspace}

        local oldGitRevision=$(cat ${workspace}/src/gitrevision)
        local newGitRevision=$(gitRevParse HEAD)
        local gitLog=$(createTempFile)

        cd ${WORKSPACE}/src
        gitLog ${oldGitRevision}..${newGitRevision} | \
            execute -n sed -e 's,^    %,%,' > ${gitLog}
        rawDebug ${gitLog}

        cd ${workspace}
        execute sed -i -e "
            s|^PKGLABEL *?=.*|PKGLABEL ?= ${releaseString}|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= ${releaseString}|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool ${releaseString}|
        " ${releaseFile}

        try
        (
            svnCommit -F gitlog ${releaseFile} ${workspace}/src/gitrevision
        )
        catch ||
        (
            setBuildResultUnstable
            local errorLineNumber=$(sed -ne 's,^Error in line \([0-9]\+\) : .*,\1,p' stderr)
            if [[ -z "${errorLineNumber}" ]] ; then
                fatal "SVN rejected our commit message for a reason we didn't understand. (see logfile)"
            fi

            for lineNumber in ${errorLineNumber} ; do
                execute sed -i -e "${lineNumber}{s,%,o/o,g;s,^,SVN REJECTED: ,}" gitlog
            done

            info "SVN rejected some of your commit notes for the release note."
            info "If you need them in the release note please do another commit"
            info "with corrected syntax."
            info "We try to commit with corrected notes."
            rawDebug gitlog

            svnCommit -F gitlog ${releaseFile} ${workspace}/src/gitrevision
        )

    done

    return
}

