#!/bin/bash

## @fn      ci_job_package()
#  @brief   create a package from the build results for the testing / release process
#  @details copy all the artifacts from the sub jobs into the workspace and create the release structure
#  @todo    implement this
#  @param   <none>
#  @return  <none>
ci_job_package() {
    info "package the build results"

    # from Jenkins: there are some environment variables, which are pointing to the downstream jobs
    # which are execute within this jenkins jobs. So we collect the artifacts from those jobs
    # and untar them in the workspace directory.

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    debug "workspace is ${workspace}"

    _copyArtifactsToWorkspace

    copyAddons
    copyVersionFile
    copyDocumentation
    copyPlatform
    copyArchs
    copySysroot
    copyFactoryZip

    copyReleaseCandidateToShare

    return 0
}

copyReleaseCandidateToShare() {

# TODO: demx2fk3 2014-04-10 not working yet...

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
 
    local label=$(getNextReleaseLabel)
    local branch=$(getBranchName)

    local localDirectory=${workspace}/upload
    local remoteDirectory=${lfsCiBuildsShare}/${branch}/data/${label}/os
    local oldRemoteDirectory=${lfsCiBuildsShare}/${branch}/data/$(ls ${lfsCiBuildsShare}/${branch}/data/ | tail -n 1 )
    local hardlink=""

    info "copy build results to ${remoteDirectory}"
    info "based on ${oldRemoteDirectory}"

    execute mkdir -p ${remoteDirectory}

    if [[ -d ${oldRemoteDirectory} ]] ; then
        hardlink="--link-dest=${oldRemoteDirectory}/os/"
    fi
    execute rsync -av --delete ${hardlink} ${localDirectory}/. ${remoteDirectory}
    echo rsync -av --delete ${hardlink} ${localDirectory}/. ${remoteDirectory}

#     executeOnMaster tar cvf transfer.tar -C ${workspace}/upload .
#     executeOnMaster mkdir -p ${lfsCiBuildsShare}/data/${label}/os/
#     # execute rsync -avrPe ssh ${workspace}/upload/* ${jenkinsMasterServerHostName}:${lfsCiBuildsShare}/data/${label}/os/
#     execute rsync -avrPe ssh transfer.tar ${linseeUlmServer}:${lfsCiBuildsShare}/data/${label}/os/
#     executeOnMaster tar xvf -C ${lfsCiBuildsShare}/data/${label}/os/ ${lfsCiBuildsShare}/data/${label}/os/transfer.tar
# 
    # TODO: demx2fk3 2014-04-10 link sdks
    executeOnMaster ln -sf ${lfsCiBuildsShare}/${branch}/data/${label} ${lfsCiBuildsShare}/${branch}/${label}
    executeOnMaster ln -sf ${lfsCiBuildsShare}/${branch}/data/${label} ${lfsCiBuildsShare}/${branch}/trunk@${BUILD_NUMBER}

    return
}

getNextReleaseLabel() {
    echo BM_LFS_REL_OS_$(date +%Y_%m)_${BUILD_NUMBER}
}

## @fn      _copyArtifactsToWorkspace()
#  @brief   copy artifacts of all releated jenkins tasks of a build to the workspace
#           based on the upstream job
#  @details «full description»
#  @param   <none>
#  @return  <none>
_copyArtifactsToWorkspace() {

    requiredParameters UPSTREAM_PROJECT LFS_CI_ROOT UPSTREAM_BUILD JOB_NAME BUILD_NUMBER

    local jobName=""
    local file=""
    local downStreamprojectsFile=$(createTempFile)
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    runOnMaster ${LFS_CI_ROOT}/bin/getDownStreamProjects -j ${UPSTREAM_PROJECT} -b ${UPSTREAM_BUILD} -h ${jenkinsMasterServerPath} > ${downStreamprojectsFile}

    if [[ $? -ne 0 ]] ; then
        error "error in getDownStreamProjects for ${JOB_NAME} #${BUILD_NUMBER}"
        exit 1
    fi
    local triggeredJobData=$( cat ${downStreamprojectsFile} )

    trace "triggered job names are: ${triggeredJobNames}"
    execute mkdir -p ${workspace}/bld/

    for jobData in ${triggeredJobData} ; do

        local buildNumber=$(echo ${jobData} | cut -d: -f 1)
        local jobResult=$(  echo ${jobData} | cut -d: -f 2)
        local jobName=$(    echo ${jobData} | cut -d: -f 3-)

        trace "jobName ${jobName} buildNumber ${buildNumber} jobResult ${jobResult}"

        if [[ ${jobResult} != "SUCCESS" ]] ; then
            error "downstream job ${jobName} was not successfull"
            exit 1
        fi

        _copyAndUntarArtifactOfJenkinsJobFromMasterToWorkspace ${jobName} ${buildNumber}

    done
}

## @fn      _copyAndUntarArtifactOfJenkinsJobFromMasterToWorkspace( $jobName, $buildName )
#  @brief   copy and untar the build artifacts from a jenkins job from the master artifacts share 
#           into the workspace
#  @param   {jobName}       jenkins job name
#  @param   {buildNumber}   jenkins buld number 
#  @param   <none>
#  @return  <none>
_copyAndUntarArtifactOfJenkinsJobFromMasterToWorkspace() {
    local jobName=$1
    local buildNumber=$2
    local artifactsPathOnMaster=${artifactesShare}/${jobName}/${buildNumber}/save/

    local files=$(runOnMaster ls ${artifactsPathOnMaster})

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    trace "artifacts files for ${jobName}#${buildNumber} on master: ${files}"
    
    for file in ${files}
    do
        local base=$(basename ${file} .tar.gz)

        if [[ -d ${workspace}/bld/${base} ]] ; then
            trace "skipping ${file}, 'cause it's already transfered from another project"
            continue
        fi
        info "copy artifact ${file} from job ${jobName}#${buildNumber} to workspace and untar it"

        execute rsync --archive --verbose --rsh=ssh -P          \
            ${linseeUlmServer}:${artifactsPathOnMaster}/${file} \
            ${workspace}/bld/

        debug "untar ${file} from job ${jobName}"
        execute tar --directory ${workspace}/bld/ \
                    --extract                     \
                    --auto-compress               \
                    --file ${workspace}/bld/${file}
        execute rm -f ${file}
    done
}

## @fn      copyAddons()
#  @brief   handle the addons, copy the addons from the results directory into the delivery structure
#  @details function checks for bld-*psl-*/results/addons directory and copy the content into the
#           regarding delivery directory
#  @param   <none>
#  @return  <none>
copyAddons() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    for bldDirectory in ${workspace}/bld/bld-*psl-* ; do
        [[ -d ${bldDirectory} ]] || continue
        [[ -d ${bldDirectory}/results/addons ]] || continue

        local destinationsPlatform=$(getArchitectureFromDirectory ${bldDirectory})
        mustHaveArchitectureFromDirectory ${bldDirectory} ${destinationsPlatform}

        info "copy addons for ${destinationsPlatform}..."

        local srcDirectory=${bldDirectory}/results/addons
        local dstDirectory=${workspace}/upload/addons/${destinationsPlatform}

        execute mkdir -p ${dstDirectory}
        execute find ${srcDirectory}/ -type f \
                    -exec cp -av {} ${dstDirectory} \;
    done

    return
}

## @fn      copyArchs()
#  @brief   handle the archs directory
#  @details «full description»
#  @param   <none>
#  @return  <none>
copyArchs() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName


    for bldDirectory in ${workspace}/bld/bld-*psl-* ; do
        [[ -d ${bldDirectory} ]] || continue

        local destinationsArchitecture=$(getArchitectureFromDirectory ${bldDirectory})
        info "handling archs for ${destinationsArchitecture}"
        # todo
        # mustHavePlatformFromDirectory ${bldDirectory} ${destinationsArchitecture} 
        local dst=${workspace}/upload/archs/${destinationsArchitecture}
        execute mkdir -p ${dst}

        execute ln -sf ../../../sdk3/bld-tools                    ${dst}/bld-tools
        execute ln -sf ../../../sdk3/dbg-tools                    ${dst}/dbg-tools
        execute ln -sf ../../sys-root/${destinationsArchitecture} ${dst}/sys-root

    done

    return
}

## @fn      copySysroot()
#  @brief   handle the sysroot directory
#  @details the method create the sysroot structure in the delivery directory.
#           if there is a sysroot.tgz, it will be untarred. Also some additional links
#           for ddal are created and ddal.pdf is copied
#  @todo    TODO: demx2fk3 2014-04-07 this is maybe not fully implemented. the else path 
#           of the if is not migrated from createBTS... I think, it's not executed any more
#  @todo    TODO: demx2fk3 2014-04-07 verify links
#  @param   <none>
#  @return  <none>
copySysroot() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName


    for bldDirectory in ${workspace}/bld/bld-*psl-* ; do

        [[ -d ${bldDirectory} ]] || continue

        local destinationsArchitecture=$(getArchitectureFromDirectory ${bldDirectory})
        mustHavePlatformFromDirectory ${bldDirectory} ${destinationsArchitecture} 

        info "copy sys-root for ${destinationsArchitecture}"

        local dst=${workspace}/upload/sys-root/${destinationsArchitecture}
        execute mkdir -p ${dst}/doc

        # check for sysroot.tgz
            # tar xvfz sysroot.tgz -C ...
            # cp DDAL.pdf doc
            # ln -sf libDDAL.so.* ..
        # else
            # find toolset
            # copy toolset include and toolset lib to .../usr
            # untar libddal header
            # copy lib
            # untar debug.tgz
            # copy some other sysroo dirs
        if [[ ${bldDirectory}/results/rfs.init_sys-root.tar.gz ]] ; then
            debug "untar results/rfs.init_sys-root.tar.gz"
            # TODO: demx2fk3 2014-04-07 expand the short parameter names
            execute tar -xzf ${bldDirectory}/results/rfs.init_sys-root.tar.gz -C ${dst}
        else
            error "missing rfs.init_sys-root.tar.gz, else path not implemented"
            exit 1
        fi

        case ${destinationsArchitecture} in
            i686-pc-linux-gnu)
                execute ln -sf ${dst}/usr/lib/libDDAL.so.fcmd libDDAL_fcmd.so
            ;;
            powerpc-e500-linux-gnu)
                execute ln -sf ${dst}/usr/lib/libDDAL.so.fcmd libDDAL_fcmd.so
                execute ln -sf ${dst}/usr/lib/libDDAL.so.fcmd libDDAL_fspc.so
            ;;
            x86_64-pc-linux-gnu)
                execute ln -sf ${dst}/usr/lib/libFSMDDAL.so.fcmd libFSMDDAL_fspc.so
            ;;
            mips64-octeon2-linux-gnu)
                execute ln -sf ${dst}/usr/lib64/libFSMDDAL.so.fct libFSMDDAL_fsm3_octeon2.so
            ;;
            mips64-octeon-linux-gnu)
                execute ln -sf ${dst}/usr/lib64/libFSMDDAL.so.fct libFSMDDAL_fsm3_octeon.so
            ;;
            *)
                error "architecture ${destinationsArchitecture} not supported"
                exit 1
            ;;
        esac            

        for file in ${bldDirectory}/results/{FSM,}DDAL.pdf ; do
            if [[ -f ${file} ]] ; then
                execute cp ${bldDirectory}/results/{FSM,}DDAL.pdf ${dst}/doc
            fi
        done

    done

    return
}

## @fn      copyFactoryZip( «param» )
#  @brief   create the factory.zip file out of platforms/fsm3_octeon2
#  @warning side effect: change the current directory (and change it back!)
#  @param   <none>
#  @return  <none>
copyFactoryZip() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dst=${workspace}/upload/platforms/fsm3_octeon2
    execute cd ${dst}
    execute zip -r factory.zip factory
    execute cd $OLDPWD

    return
}

## @fn      copyPlatform(  )
#  @brief   handle the platform directory in the delivery structure
#  @details «full description»
#  @param   <none>
#  @return  <none>
copyPlatform() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    for bldDirectory in ${workspace}/bld/bld-*psl-* ; do
        [[ -d ${bldDirectory} ]] || continue
        [[ -d ${bldDirectory}/results ]] || continue

        local architecture=$(getPlatformFromDirectory ${bldDirectory})
        mustHavePlatformFromDirectory ${bldDirectory} ${architecture}

        local dst=${workspace}/upload/platforms/${architecture}
        execute mkdir -p ${dst}

        info "copy platform for ${architecture}..."

        # TODO: demx2fk3 2014-04-07 expand the short parameter names
        execute rsync -avr --exclude=addons --exclude=sys-root --exclude=rfs.init_sys-root.tar.gz ${bldDirectory}/results/. ${dst}

        debug "symlink addons"
        execute ln -sf ../../addons/${architecture} ${dst}/addons

        debug "symlinks sys-root"
        execute ln -sf ../../sys-root/${architecture} ${dst}/sys-root

        debug "cleanup stuff in platform ${architecture}"

        case ${architecture} in
            qemu)        : ;;  # no op
            fcmd | fspc) : ;;  # no op
            qemu_64)
                    mkdir ${dst}/devel
                    for file in ${dst}/config     \
                                ${dst}/System.map \
                                ${dst}/vmlinux.*  \
                                ${dst}/uImage.nfs
                    do
                        [[ -f ${file} ]] || continue
                        execute mv -f ${file} ${dst}/devel
                    done
            ;;
            fsm3_octeon2)
                    ln -fs factory/u-boot.uim ${dst}/u-boot.uim
                    mkdir ${dst}/devel
                    for file in ${dst}/config     \
                                ${dst}/rootfs*    \
                                ${dst}/System.map \
                                ${dst}/uImage.nfs \
                                ${dst}/vmlinux.*
                    do
                        [[ -f ${file} ]] || continue
                        execute mv -f ${file} ${dst}/devel
                    done
                    rm -f ${dst}/bzImage
            ;;
        esac

    done

    return
}

## @fn      copyVersionFile()
#  @brief   copy version control file into the delivery structure
#  @param   <none>
#  @return  <none>
copyVersionFile() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dstDirectory=${workspace}/upload/versions
    mkdir -p ${dstDirectory}

    # TODO: demx2fk3 2014-04-01 implement this, fix in src-fsmpsl and src-psl is needed

    info "copy verson control file..."

    for file in ${workspace}/bld/bld-fsmpsl-fct/results/doc/versions/version_control.xml \
                ${workspace}/bld/bld-fsmpsl-fct/results/doc/versions/ptsw_fsmr3_version_control.xml \
                ${workspace}/bld/bld-fsmpsl-fct/results/doc/versions/ptsw_urec_version_control.xml
    do
        [[ -e ${file} ]] || continue
        execute cp ${file} ${dstDirectory}
    done

    return
}

## @fn      copyDocumentation()
#  @brief   copy the documentation into the delivery structure
#  @param   <none>
#  @return  <none>
copyDocumentation() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dstDirectory=${workspace}/upload/doc
    mkdir -p ${dstDirectory}

    info "copy doc..."

    # TODO: demx2fk3 2014-04-01 implement this, fix in src-fsmpsl and src-psl is needed

    return
}


## @fn      getArchitectureFromDirectory( $dir )
#  @brief   get the arcitecture from the bld directory
#  @details maps e.g. fct to mips64-octeon2-linux-gnu
#           see also mapping on config.sh
#  @param   {directory}    a bld directory name
#  @return  architecture
getArchitectureFromDirectory() {
    local directory=$1
    baseName=$(basename ${directory})
    directoryPlatform=$(cut -d- -f3 <<< ${baseName})
    echo ${archMap["${directoryPlatform}"]}
    return
}

## @fn      getPlatformFromDirectory( $dir )
#  @brief   get the platform from the bld directory
#  @details maps e.g. fct to fsm3_octeon2
#           see also mapping in config.sh
#  @param   {directory}    a bld directory name
#  @return  platform
getPlatformFromDirectory() {
    local directory=$1
    baseName=$(basename ${directory})
    directoryPlatform=$(cut -d- -f3 <<< ${baseName})
    destinationsPlatform=${platformMap["${directoryPlatform}"]}
    echo ${destinationsPlatform}
    return
}

## @fn      mustHaveArchitectureFromDirectory( $dir, $arch )
#  @brief   ensure, that there is a architecture name
#  @param   {dir}             the bld directory name
#  @param   {architecture}    the architecture
#  @return  <none>
#  @return  1 if there is no archtecutre, 0 otherwise
mustHaveArchitectureFromDirectory() {
    local directory=$(basename $1)
    local architecture=$2
    if [[ ! ${architecture} ]] ; then
        error "can not found map for architecture ${directory}"
        exit 1
    fi
    return
}

## @fn      mustHavePlatformFromDirectory( $dir, $arch )
#  @brief   ensure, that there is a platform name
#  @param   {dir}             the bld directory name
#  @param   {architecture}    the platform
#  @return  <none>
#  @return  1 if there is no platform, 0 otherwise
mustHavePlatformFromDirectory() {
    local directory=$(basename $1)
    local platform=$2
    if [[ ! ${platform} ]] ; then
        error "can not found map for platform ${directory}"
        exit 1
    fi
    return
}

return 0

