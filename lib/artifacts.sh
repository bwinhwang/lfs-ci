#!/bin/bash
## @file    artifacts.sh
#  @brief   handling of artifacts of a build
#  @details There is/was a problem in jenkins with artifacts handling.
#           Espesally if we handling very big artifacts bigger than a few hundert MB.
#           So we doing the handling of artifacts by yourself within the scripting.
#           The artifacts are stored on the linsee share /build/home/psulm/LFS_internal/artifacts
#           with the <jobName>/<buildNumber>.
#           
#           The cleanup of the share will be handled within the uc_admin.sh.
#           

LFS_CI_SOURCE_artifacts='$Id$'

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
    requiredParameters JOB_NAME BUILD_NUMBER

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustExistDirectory "${workspace}/bld/"

    # TODO: demx2fk3 2014-03-31 remove cd - changing the current directory isn't a good idea!
    cd "${workspace}/bld/" 
    for dir in bld-*-* ; do
        [[ -d "${dir}" && ! -L "${dir}" ]] || continue

        # TODO: demx2fk3 2014-08-08 fixme - does not work
        # [[ -f "${dir}.tar.gz" ]] || continue

        local subsystem=$(cut -d- -f2 <<< ${dir})
        info "creating artifact archive for ${dir}"
        execute tar --create --use-compress-program=${LFS_CI_ROOT}/bin/pigz --file "${dir}.tar.gz" "${dir}"
        copyFileToArtifactDirectory ${dir}.tar.gz
    done

    local shouldCreateReadMeFile=$(getConfig LFS_CI_create_artifact_archive_should_create_dummy_readme_file)
    if [[ ${shouldCreateReadMeFile} ]] ; then
        local readmeFile=${workspace}/bld/.00_README_these_arent_the_files_you_are_looking_for.txt
        cat > ${readmeFile} <<EOF
Dear User,

These aren't the files you're looking for[1].
Please check the artifacts of the package job

Your LFS SCM Team

[1] https://www.youtube.com/watch?v=DIzAaY2Jm-s&t=190
EOF

        copyFileToArtifactDirectory $(basename ${readmeFile})
    fi

    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}

    return 
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

    copyAndExtractBuildArtifactsFromProject "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}"

    return
}

## @fn      copyAndExtractBuildArtifactsFromProject()
#  @brief   copy and untar the build artifacts from a jenkins job from the master artifacts share 
#           into the workspace
#  @param   {jobName}       jenkins job name
#  @param   {buildNumber}   jenkins buld number 
#  @param   <none>
#  @return  <none>
copyAndExtractBuildArtifactsFromProject() {
    local jobName=$1
    local buildNumber=$2
    local allowedComponentsFilter="$3"

    [[ -z ${jobName} ]] && return

    local artifactesShare=$(getConfig artifactesShare)
    local artifactsPathOnMaster=${artifactesShare}/${jobName}/${buildNumber}/save/
    local serverName=$(getConfig LFS_CI_artifacts_storage_host)

    local files=$(runOnMaster ls ${artifactsPathOnMaster} 2>/dev/null)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    debug "checking for build artifacts on share of project (${jobName}/${buildNumber})"
    trace "artifacts files for ${jobName}#${buildNumber} on master: ${files}"

    execute mkdir -p ${workspace}/bld/

    for file in ${files}
    do
        local base=$(basename ${file} .tar.gz)
        local component=$(cut -d- -f2 <<< ${base})

        if [[ "${allowedComponentsFilter}" ]] ; then
            if ! grep -q " ${component} " <<< " ${allowedComponentsFilter} " ; then
                debug "${component} / ${base} artifact was filtered out"
                continue
            fi
        fi

        if [[ -d ${workspace}/bld/${base} ]] ; then
            trace "skipping ${file}, 'cause it's already transfered from another project"
            continue
        fi

        info "copy artifact ${file} from job ${jobName}#${buildNumber} to workspace and untar it"

        execute -r 10 rsync --archive --verbose --rsh=ssh -P          \
            ${serverName}:${artifactsPathOnMaster}/${file} \
            ${workspace}/bld/

        debug "untar ${file} from job ${jobName}"
        execute tar --directory ${workspace}/bld/ \
                    --extract                     \
                    --use-compress-program=${LFS_CI_ROOT}/bin/pigz \
                    --file ${workspace}/bld/${file}
    done

    return
}

## @fn      copyArtifactsToWorkspace()
#  @brief   copy artifacts of all releated jenkins tasks of a build to the workspace
#           based on the upstream job
#  @param   <none>
#  @return  <none>
copyArtifactsToWorkspace() {
    local jobName=$1
    local buildNumber=$2
    local allowedComponentsFilter="$3"

    requiredParameters LFS_CI_ROOT

    info "copy artifacts to workspace for ${jobName} / ${buildNumber} with filter ${allowedComponentsFilter}"

    local file=""
    local downStreamprojectsFile=$(createTempFile)
    local serverPath=$(getConfig jenkinsMasterServerPath)
    mustHaveValue "${serverPath}" "server path"
    # TODO: demx2fk3 2015-03-09 FIXME SSH_LOAD replace this with other server
    local server=$(getConfig jenkinsMasterServerHostName)
    mustHaveValue "${server}" "server name"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    execute -n -r 10 ssh ${server} \
            /ps/lfs/ci/bin/getDownStreamProjects -j ${jobName}     \
                                                 -b ${buildNumber} \
                                                 -h ${serverPath} > ${downStreamprojectsFile}

    if [[ $? -ne 0 ]] ; then
        error "error in getDownStreamProjects for ${jobName} #${buildNumber}"
        exit 1
    fi
    if [[ ! -s  ${downStreamprojectsFile} ]] ; then
        printf "%d:SUCCESS:%s" ${buildNumber} ${jobName} > ${downStreamprojectsFile}
    fi

    local triggeredJobData=$(cat ${downStreamprojectsFile})
    # mustHaveValue "${triggeredJobData}" "triggered job data"

    trace "triggered job names are: ${triggeredJobNames}"
    execute mkdir -p ${workspace}/bld/

    for jobData in ${triggeredJobData} ; do
        local number=$(echo ${jobData} | cut -d: -f 1)
        local result=$(echo ${jobData} | cut -d: -f 2)
        local name=$(  echo ${jobData} | cut -d: -f 3-)

        [[ ${result} = NOT_BUILT ]] && continue

        trace "jobName ${name} buildNumber ${nuber} jobResult ${result}"

        if [[ ${result} != "SUCCESS" && ${result} != "NOT_BUILT" ]] ; then
            error "downstream job ${name} has ${result}. Was not successfull"
            exit 1
        fi

        copyAndExtractBuildArtifactsFromProject ${name} ${number} "${allowedComponentsFilter}"
    done

    return
}

## @fn      copyFileToArtifactDirectory()
#  @brief   copy a file to the artifacts directory of the current build
#  @param   {fileName}    path and name of the file
#  @detail  see also linkFileToArtifactsDirectory
#  @return  <none>
copyFileToArtifactDirectory() {
    requiredParameters JOB_NAME BUILD_NUMBER
    local fileName=$1

    local serverName=$(getConfig LFS_CI_artifacts_storage_host)
    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    # executeOnMaster mkdir -p ${artifactsPathOnShare}/save
    execute -r 10 ssh ${serverName} mkdir -p ${artifactsPathOnShare}/save

    # sometimes, the remote host closes connection, so we try to retry...
    execute -r 10 rsync --archive --verbose --rsh=ssh -P  \
        ${fileName}                                 \
        ${serverName}:${artifactsPathOnShare}/save

    return
}

## @fn      copyFileToUserContentDirectory()
#  @brief   copy a file to the artifacts userContent directory
#  @param   {fileName}    path and name of the file
#  @return  <none>
copyFileToUserContentDirectory() {
    requiredParameters JOB_NAME BUILD_NUMBER
    local fileName=$1

    local serverName=$(getConfig jenkinsMasterServerHostName)
    local sonarPathOnServer=$(getConfig jenkinsMasterServerPath)/userContent/sonar
    # executeOnMaster mkdir -p ${artifactsPathOnShare}/save
    execute -r 10 ssh ${serverName} mkdir -p ${sonarPathOnServer}

    # sometimes, the remote host closes connection, so we try to retry...
    execute -r 10 rsync --archive --verbose --rsh=ssh -P  \
        ${fileName}                                 \
        ${serverName}:${sonarPathOnServer}

    return
}

## @fn      linkFileToArtifactsDirectory()
#  @brief   create a symlkink from the given name to the artifacts folder on the master.
#  @warning the given fileName must be accessable via nfs from the master. otherwise, the
#           link will not work in jenkins
#  @param   {fileName}    name of the file
#  @param   {linkName}    name of the link (can be empty)
#  @return  <none>
linkFileToArtifactsDirectory() {
    local linkSource=$1
    local linkDestination=$2

    info "create link to artifacts"
    local artifactesShare=$(getConfig artifactesShare)
    local artifactsPathOnMaster=$(getBuildDirectoryOnMaster)/archive
    executeOnMaster mkdir -p  ${artifactsPathOnMaster}
    executeOnMaster ln    -sf ${linkSource} ${artifactsPathOnMaster}

    return
}

