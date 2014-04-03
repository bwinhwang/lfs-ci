#!/bin/bash

dumpCustomScmEnvironmentVariables() {
    for var in BUILD_DIR               \
               BUILD_NUMBER            \
               BUILD_URL               \
               BUILD_URL_LAST          \
               BUILD_URL_LAST_STABLE   \
               BUILD_URL_LAST_SUCCESS  \
               CHANGELOG               \
               JENKINS_HOME            \
               JENKINS_URL             \
               JOB_DIR                 \
               JOB_NAME                \
               OLD_REVISION_STATE_FILE \
               REVISION_STATE_FILE     \
               UPSTREAM_BUILD          \
               UPSTREAM_JOB_URLS       \
               UPSTREAM_PROJECT        \
               WORKSPACE 
    do
        debug "$(printf "%30s %-30s\n" "${var}" "${!var}")"
    done

    return
}

createPropertiesFileForBuild() {
    execute rm -rf ${WORKSPACE}/.properties
    echo UPSTREAM_BUILD=${UPSTREAM_BUILD}     >  ${WORKSPACE}/.properties
    echo UPSTREAM_PROJECT=${UPSTREAM_PROJECT} >> ${WORKSPACE}/.properties
    return
}


actionCompare() {
    if [[ -z "${REVISION_STATE_FILE}" ]] ; then
        info "no old revision state file found"
        exit 0
    fi

    { read oldUpstreamProjectName ; read oldUpstreamBuildNumber ;  } < "${REVISION_STATE_FILE}"

    if [[ ${oldUpstreamProjectName} != ${UPSTREAM_PROJECT} ]] ; then
        info "old upstream project name has changed, trigger new build"
        exit 0
    fi
    if [[ ${oldUpstreamBuildNumber} != ${UPSTREAM_BUILD} ]] ; then
        info "upstream build number has changed, need to trigger build"
        exit 0
    fi

    echo "upstream build ${UPSTREAM_PROJECT}#${UPSTREAM_BUILD} has already been tested, will not trigger a new build"
    echo 1
}
actionCheckout() {
    # changelog handling
    # idea: the upstream project has the correct change log. We have to get it from them.
    # For this, we get the old revision state file and the revision state file.
    # This includes the upstream project name and the upstream build number.
    # So the job is easy: get the changelog of the upstream project builds between old and new
    #
    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"

    echo "get the old upstream project data..."
    { read oldUpstreamProjectName ; read oldUpstreamBuildNumber ;  } < "${OLD_REVISION_STATE_FILE}"
    echo "old upstream project data are: ${oldUpstreamProjectName} / ${oldUpstreamBuildNumber}"

    build=${UPSTREAM_BUILD}
    while [[ ${build} -gt ${oldUpstreamBuildNumber} ]] ; do
        buildDirectory=/var/fpwork/demx2fk3/lfs-jenkins/home/jobs/${UPSTREAM_PROJECT}/builds/${build}
        # we must only concatenate non-empty logs; empty logs with a
        # single "<log/>" entry will break the concatenation:
        ssh maxi.emea.nsn-net.net "grep -q logentry \"${buildDirectory}/changelog.xml\" && cat \"${buildDirectory}/changelog.xml\"" >> ${CHANGELOG}
        build=$(( build - 1 ))
    done

    # Remove inter-log cruft arising from the concatenation of individual
    # changelogs:
    sed -i 's:</log><?xml[^>]*><log>::g' "$CHANGELOG"

    # Fix empty changelogs:
    if [ ! -s "$CHANGELOG" ] ; then
        echo -n "<log/>" >"$CHANGELOG"
    fi

        echo ${UPSTREAM_PROJECT}   >   "${REVISION_STATE_FILE}"
        echo ${UPSTREAM_BUILD}     >>  "${REVISION_STATE_FILE}"


     exit 0
}

actionCalculate() {
    return 
}

return
