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

    info "pkgpool release name prefix is ${releasePrefix}"

    local buildLogFile=$(createTempFile)
    local gitWorkspace=${WORKSPACE}/src

    # git clone, created by jenkins git plugin
    mustExistDirectory ${gitWorkspace}

    info "preparing git workspace..."
    cd ${gitWorkspace}
    execute rm -rf ${gitWorkspace}/src
    gitReset --hard

    info "bootstrap build environment..."
    execute ./bootstrap
    cd ${workspace}

    info "building pkgpool..."
    # TODO: demx2fk3 2015-02-09 use different path for testing ci jobs
    execute -l ${buildLogFile} ${gitWorkspace}/build -j100 --pkgpool=/build/home/psulm/SC_LFS/pkgpool --prepopulate --release="${releasePrefix}" 

    local releaseTag="$(execute -n sed -ne 's,^release \([^ ]*\) complete,\1,p' ${buildLogFile})"
    mustHaveValue "${releaseTag}" "release tag"

    info "new pkgpool release tag is ${releaseTag}"

    cd ${gitWorkspace}
    local oldReleaseTag=$(gitDescribe --abbrev=0)
    gitTagAndPushToOrigin ${releaseTag}

    local gitRevision=$(gitRevParse HEAD)

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${releaseTag}"

    # TODO: demx2fk3 2015-02-25 FIXME hardcoded path
    # required to start the sync 
    execute touch /build/home/psulm/SC_LFS/pkgpool/.hashpool

    mkdir -p ${workspace}/bld/bld-pkgpool-release/
    echo ${oldReleaseTag}                   > ${workspace}/bld/bld-pkgpool-release/oldLabel
    echo ${releaseTag}                      > ${workspace}/bld/bld-pkgpool-release/label
    echo ${gitRevision}                     > ${workspace}/bld/bld-pkgpool-release/gitrevision

    execute -n sed -ne 's|^src [^ ]* \(.*\)$|PS_LFS_PKG = \1|p' ${workspace}/pool/*.meta |\
        sort -u > ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt

    rawDebug ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt

    createArtifactArchive

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

    # location and product name is needed in sendReleaseNote
    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"
    local location=$(getLocationName)
    mustHaveValue "${location}" "location"

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

    # TODO: demx2fk3 2015-02-05 baselines list missing
    echo "<log/>" > ${workspace}/changelog.xml
    cd ${workspace}
    export productName=PKGPOOL
    execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML \
                -t ${label}                         \
                -o ${oldLabel}                      \
                -f ${LFS_CI_ROOT}/etc/file.cfg > ${workspace}/releasenote.xml
    
    rawDebug ${workspace}/releasenote.xml

    mustBeValidXmlReleaseNote ${workspace}/releasenote.xml

    local releaseNoteTxt=${workspace}/releasenote.txt
    execute touch ${releaseNoteTxt}
    execute -i -l ${releaseNoteTxt} diff -y -W72 -t --suppress-common-lines \
        ${workspace}/forReleaseNote.txt.old \
        ${workspace}/bld/bld-pkgpool-release/forReleaseNote.txt

    rawDebug ${releaseNoteTxt}

    local canCreateReleaseinWft=$(getConfig LFS_CI_uc_release_can_create_release_in_wft)
    if [[ ${canCreateReleaseinWft} ]] ; then
        # createReleaseInWorkflowTool ${label} ${workspace}/releasenote.xml
        # uploadToWorkflowTool        ${label} ${workspace}/releasenote.xml
        true
    else
        warning "creating release not in WFT is disabled via config"
    fi

    local canSendReleaseNote=$(getConfig LFS_CI_uc_release_can_send_release_note)
    if [[ ${canSendReleaseNote} ]] ; then
        if [[ -s ${releaseNoteTxt} ]] ; then
            execute ${LFS_CI_ROOT}/bin/sendReleaseNote  -r ${releaseNoteTxt}          \
                                                        -t ${label}                   \
                                                        -f ${LFS_CI_ROOT}/etc/file.cfg
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

    copyArtifactsToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "pkgpool"

    local label=$(cat ${workspace}/bld/bld-pkgpool-release/label)
    mustHaveValue "${label}" "label"

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

    local oldLabel=$(cat ${workspace}/bld/bld-pkgpool-release/oldLabel)
    mustHaveValue "${oldLabel}" "old label"

    local newGitRevision=$(cat ${workspace}/bld/bld-pkgpool-release/gitrevision)
    mustHaveValue "${newGitRevision}" "new git revision"

    gitClone ssh://git@psulm.nsn-net.net/build/build ${WORKSPACE}/src

    local svnUrlsToUpdate=$(getConfig PKGPOOL_PROD_update_dependencies_svn_url)
    mustHaveValue "${svnUrlsToUpdate}" "svn urls for pkgpool"


    local urlToUpdate=""

    for urlToUpdate in ${svnUrlsToUpdate} ; do
        info "url to update ${urlToUpdate}"

        local releaseFile=$(basename ${urlToUpdate})
        local svnUrl=$(dirname ${urlToUpdate})

        local workspace=$(getWorkspaceName)
        mustHaveWorkspaceName

        svnCheckout ${svnUrl} ${workspace}

        local gitLog=$(createTempFile)
        cd ${WORKSPACE}/src
        local oldGitRevision=$(cat ${workspace}/src/gitrevision)
        mustHaveValue "${oldGitRevision}" "old git revision"

        gitLog ${oldGitRevision}..${newGitRevision} | \
            sed -e 's,^    %,%,' > ${gitLog}
        rawDebug ${gitLog}

        cd ${workspace}
        execute sed -i -e "
            s|^PKGLABEL *?=.*|PKGLABEL ?= ${releaseString}|
            s|^LRCPKGLABEL *?=.*|LRCPKGLABEL ?= ${releaseString}|
            s|^hint *bld/pkgpool .*|hint bld/pkgpool ${releaseString}|
        " ${releaseFile}

        export LFS_CI_LAST_EXECUTE_LOGFILE=$(createTempFile)
        try
        (
            svnCommit -F gitlog ${releaseFile} ${workspace}/src/gitrevision
        )
        catch ||
        (
            warning "first svn commit failed, try to correct from error log"

            # logfile from the last execution command (in svnCommit)
            errorLogFile=$(lastExecuteLogFile)
            mustExistFile ${errorLogFile}

            setBuildResultUnstable

            local errorLineNumber=$(sed -ne 's,^Error in line \([0-9]\+\) : .*,\1,p' ${errorLogFile})
            if [[ -z "${errorLineNumber}" ]] ; then
                fatal "SVN rejected our commit message for a reason we didn't understand. (see logfile)"
            fi

            for lineNumber in ${errorLineNumber} ; do
                execute sed -i -e "${lineNumber}{s,%,o/o,g;s,^,SVN REJECTED: ,}" gitlog
            done

            warning "SVN rejected some of your commit notes for the release note."
            warning "If you need them in the release note please do another commit"
            warning "with corrected syntax."
            warning "We try to commit with corrected notes."
            rawDebug gitlog

            svnCommit -F gitlog ${releaseFile} ${workspace}/src/gitrevision
        ) || exit 1 # when catch part also fails, we exit the usecase

        info "update done for ${urlToUpdate}"
    done

    return
}

