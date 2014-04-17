#!/bin/bash

## @fn      createArtifactArchive()
#  @brief   create the build artifacts archives and copy them to the share on the master server
#  @details the build artifacts are not handled by jenkins. we are doing it by ourself, because
#           jenkins can not handle artifacts on nfs via slaves very well.
#           so we create a tarball of each bld/* directory. this tarball will be moved to the master
#           on the /build share. Jenkins will see the artifacts, because we creating a link from
#           the build share to the jenkins build directory
#  @param   <none>
#  @return  <none>
createArtifactArchive() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    # TODO: demx2fk3 2014-04-17 add mustHaveBuildResultsDirectory here
    # TODO: demx2fk3 2014-03-31 remove cd - dont change the current directory
    cd "${workspace}/bld/"

    local artifactsPathOnShare=${artifactesShare}/${JOB_NAME}/${BUILD_NUMBER}
    local artifactsPathOnMaster=${jenkinsMasterServerPath}/jobs/${JOB_NAME}/builds/${BUILD_NUMBER}/archive
    executeOnMaster mkdir -p  ${artifactsPathOnShare}/save
    executeOnMaster ln    -sf ${artifactsPathOnShare}      ${artifactsPathOnMaster}

    for dir in bld-*-* ; do
        [[ -d "${dir}" && ! -L "${dir}" ]] || continue
        info "creating artifact archive for ${dir}"
        execute tar --create --auto-compress --file "${dir}.tar.gz" "${dir}"
        execute rsync --archive --verbose --rsh=ssh -P     \
            "${dir}.tar.gz"                                \
            ${linseeUlmServer}:${artifactsPathOnShare}/save
    done

    return 0
}

## @fn      mustHaveBuildArtifactsFromUpstream()
#  @brief   ensure, that the job has the artifacts from the upstream projekt, if exists
#  @detail  the method check, if there is a upstream project is set and if this project has
#           artifacts. If this is true, it copies the artifacts to the workspace bld directory
#           and untar the artifacts.
#  @param   <none>
#  @return  <none>
mustHaveBuildArtifactsFromUpstream() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    copyAndextractBuildArtifactsFromProject "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}"

    return
}

copyAndextractBuildArtifactsFromProject() {
    local jobName=$1
    local buildNumber=$2

    local workspace=$(getWorkspaceName)

    debug "checking for build artifacts on share of upstream project"

    if runOnMaster test -d ${artifactesShare}/${jobName}/${buildNumber}/save/ 
    then
        info "copy artifacts of ${jobName} #${buildNumber} from master"
        execute mkdir -p ${workspace}/bld/
        execute rsync --archive --verbose -P --rsh=ssh                                         \
            ${linseeUlmServer}:${artifactesShare}/${jobName}/${buildNumber}/save/. \
            ${workspace}/bld/.

        for file in ${workspace}/bld/*.tar.{gz,xz,bz2}
        do
            [[ -f ${file} ]] || continue
            info "untaring build artifacts ${file}"
            execute tar -C ${workspace}/bld/ --extract --auto-compress --file ${file}
        done
    fi

    return
}

