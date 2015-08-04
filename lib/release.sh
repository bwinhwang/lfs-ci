#!/bin/bash

mustBePreparedForReleaseTask() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD \
                       JOB_NAME         BUILD_NUMBER

    info "upstream project is ${UPSTREAM_PROJECT} / ${UPSTREAM_PROJECT}"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHavePreparedWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}

    mustHaveNextCiLabelName
    local releaseLabel=$(getNextReleaseLabel)
    mustHaveValue "${releaseLabel}" "release label"

    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${releaseLabel}
    mustExistDirectory ${releaseDirectory}
    info  "found release on share: ${releaseDirectory}"

    # storing new and old label name into files for later use and archive
    execute mkdir -p ${workspace}/bld/bld-lfs-release/
    echo ${releaseLabel} > ${workspace}/bld/bld-lfs-release/label.txt
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} \
            ${workspace}/bld/bld-lfs-release/label.txt

    local releaseSummaryJobName=${JOB_NAME//${subJob}/summary}
    info "release job name is ${releaseSummaryJobName}"

    # TODO: demx2fk3 2015-08-04 FIXME we have to find the change log in the correct way.
    #                           Maybe we have to modify custom scm release script.
    local lastSuccessfulBuildDirectory=$(getBuildDirectoryOnMaster ${releaseSummaryJobName} lastSuccessfulBuild)
    if runOnMaster test -e ${lastSuccessfulBuildDirectory}/label.txt ; then
        copyFileFromBuildDirectoryToWorkspace ${releaseSummaryJobName} lastSuccessfulBuild label.txt
        execute mv ${WORKSPACE}/label.txt ${workspace}/bld/bld-lfs-release/oldLabel.txt
    else
        # TODO: demx2fk3 2014-08-08 this should be an error message.
        # TODO: demx2fk3 2015-08-04 should be retrieved from the database
        local basedOn=$(getConfig LFS_PROD_uc_release_based_on)
        echo ${basedOn} > ${workspace}/bld/bld-lfs-release/oldLabel.txt
    fi

    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=$(cat ${workspace}/bld/bld-lfs-release/label.txt)
    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME=$(cat ${workspace}/bld/bld-lfs-release/oldLabel.txt)
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL=${LFS_PROD_RELEASE_CURRENT_TAG_NAME//PS_LFS_OS_/PS_LFS_REL_}
    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL=${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME//PS_LFS_OS_/PS_LFS_REL_}

    info "LFS os release ${LFS_PROD_RELEASE_CURRENT_TAG_NAME} is based on ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}"
    info "LFS release ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL} is based on ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL}"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" \
        "<a href=https://wft.inside.nsn.com/ALL/builds/${releaseLabel}>${releaseLabel}</a><br>
         <a href=https://wft.inside.nsn.com/ALL/builds/${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}>${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}</a>"

    return
}

