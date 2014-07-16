#!/bin/bash

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
    local serverPath=$(getConfig jenkinsMasterServerPath)
    local serverName=$(getConfig linseeUlmServer)
    mustHaveWorkspaceName

    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    executeOnMaster mkdir -p ${artifactsPathOnShare}/save
    mustExistDirectory ${artifactsPathOnShare}
    mustExistDirectory "${workspace}/bld/"

    # TODO: demx2fk3 2014-03-31 remove cd - changing the current directory isn't a good idea!
    cd "${workspace}/bld/" 
    for dir in bld-*-* ; do
        [[ -d "${dir}" && ! -L "${dir}" ]] || continue

        local subsystem=$(cut -d- -f2 <<< ${dir})
        case ${subsystem} in
            kernelsources)
                debug "skipping ${dir}"
                continue
            ;;
        esac

        info "creating artifact archive for ${dir}"
        execute tar --create --auto-compress --file "${dir}.tar.gz" "${dir}"
        execute rsync --archive --verbose --rsh=ssh -P     \
            "${dir}.tar.gz"                                \
            ${serverName}:${artifactsPathOnShare}/save
    done

    createSymlinksToArtifactsOnShare ${artifactsPathOnShare}

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

## @fn      copyAndExtractBuildArtifactsFromProject( $jobName, $buildName )
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
    local artifactesShare=$(getConfig artifactesShare)
    local artifactsPathOnMaster=${artifactesShare}/${jobName}/${buildNumber}/save/
    local serverName=$(getConfig linseeUlmServer)

    local files=$(runOnMaster ls ${artifactsPathOnMaster})

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

        execute rsync --archive --verbose --rsh=ssh -P          \
            ${serverName}:${artifactsPathOnMaster}/${file} \
            ${workspace}/bld/

        debug "untar ${file} from job ${jobName}"
        execute tar --directory ${workspace}/bld/ \
                    --extract                     \
                    --auto-compress               \
                    --file ${workspace}/bld/${file}
    done

    return
}

## @fn      copyArtifactsToWorkspace()
#  @brief   copy artifacts of all releated jenkins tasks of a build to the workspace
#           based on the upstream job
#  @details «full description»
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
    mustHaveValue "${serverPath}"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    runOnMaster ${LFS_CI_ROOT}/bin/getDownStreamProjects -j ${jobName}     \
                                                         -b ${buildNumber} \
                                                         -h ${serverPath} > ${downStreamprojectsFile}

    if [[ $? -ne 0 ]] ; then
        error "error in getDownStreamProjects for ${jobName} #${buildNumber}"
        exit 1
    fi

    local triggeredJobData=$(cat ${downStreamprojectsFile})
    # mustHaveValue "${triggeredJobData}" "triggered job data"

    trace "triggered job names are: ${triggeredJobNames}"
    execute mkdir -p ${workspace}/bld/

    for jobData in ${triggeredJobData} ; do
        local number=$(echo ${jobData} | cut -d: -f 1)
        local result=$(echo ${jobData} | cut -d: -f 2)
        local name=$(  echo ${jobData} | cut -d: -f 3-)

        trace "jobName ${name} buildNumber ${nuber} jobResult ${result}"

        if [[ ${result} != "SUCCESS" ]] ; then
            error "downstream job ${name} has ${result}. Was not successfull"
            exit 1
        fi

        copyAndExtractBuildArtifactsFromProject ${name} ${number} "${allowedComponentsFilter}"
    done

    return
}

createSymlinksToArtifactsOnShare() {
    requiredParameters JOB_NAME BUILD_NUMBER

    local artifactsDirectoryOnShare=$1
    mustExistDirectory ${artifactsDirectoryOnShare}

    info "create link to artifacts"
    local artifactesShare=$(getConfig artifactesShare)
    local artifactsPathOnMaster=$(getBuildDirectoryOnMaster)/archive
    executeOnMaster mkdir -p  ${artifactsDirectoryOnShare}/save
    executeOnMaster ln    -sf ${artifactsDirectoryOnShare} ${artifactsPathOnMaster}

    return
}
