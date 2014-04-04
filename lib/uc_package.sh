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

    trace "workspace is ${workspace}"

    local jobName=""
    local file=""

    local downStreamprojectsFile=$(createTempFile)
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

        local artifactsPathOnMaster=${artifactesShare}/${jobName}/${buildNumber}/save/

        local files=$(runOnMaster ls ${artifactsPathOnMaster})
        trace "artifacts files for ${jobName}#${buildNumber} on master: ${files}"

        for file in ${files}
        do
            local base=$(basename ${file} .tar.gz)

            if [[ -d ${workspace}/bld/${base} ]] ; then 
                trace "skipping ${file}, 'cause it's already transfered from another project"
                continue
            fi
            info "copy artifact ${file} from job ${jobName}#${buildNumber} to workspace and untar it"

            execute rsync --archive --verbose --rsh=ssh -P                      \
                ${jenkinsMasterServerHostName}:${artifactsPathOnMaster}/${file} \
                ${workspace}/bld/

            debug "untar ${file} from job ${jobName}"
            execute tar --directory ${workspace}/bld/ --extract --auto-compress --file ${workspace}/bld/${file}
            execute rm -f ${file}
        done
    done

    copyAddons
    copyVersionFile
    copyDocumentation
    copyPlatform

    return 0
}


copyAddons() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    for bldDirectory in ${workspace}/bld/bld-*psl-* ; do
        [[ -d ${bldDirectory} ]] || continue
        [[ -d ${bldDirectory}/results/addons ]] || continue

        local destinationsPlatform=$(getPlatformFromDirectory ${bldDirectory})
        mustHavePlatformFromDirectory ${bldDirectory} ${destinationsPlatform}

        info "copy addons for ${destinationsPlatform}..."

        local srcDirectory=${bldDirectory}/results/addons
        local dstDirectory=${workspace}/upload/addons/${destinationsPlatform}

        execute mkdir -p ${dstDirectory}
        execute find ${srcDirectory}/ -type f -exec cp -av {} ${dstDirectory} \;

    done

    return
}

copyArchs() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dst=${workspace}/upload/archs/
    execute mkdir -p ${dst}

    ln -sf ../../../sdk3/bld-tools ${dst}/archs/$SYSARCH/bld-tools                                                                                                                                                          
    ln -sf ../../../sdk3/dbg-tools ${dst}/archs/$SYSARCH/dbg-tools                                                                                                                                                          
    ln -sf ../../sys-root/$SYSARCH ${dst}/archs/$SYSARCH/sys-root

    return
}

copyPlatform() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName


    for bldDirectory in ${workspace}/bld/bld-*psl-* ; do
        [[ -d ${bldDirectory} ]] || continue
        [[ -d ${bldDirectory}/results ]] || continue

        local destinationsPlatform=$(getPlatformFromDirectory ${bldDirectory})
        mustHavePlatformFromDirectory ${bldDirectory} ${destinationsPlatform}

        local dst=${workspace}/upload/platforms/${destinationsPlatform}
        execute mkdir -p ${dst}

        info "copy platform for ${destinationsPlatform}..."

        execute rsync -avr --exclude=addons --exclude=sys-root --exclude=rfs.init_sys-root.tar.gz ${bldDirectory}/results/. ${dst}

        debug "symlink addons"
        execute ln -sf ../../addons/${destinationsPlatform} ${dst}/addons

        debug "symlinks sys-root"
        execute ln -sf ../../sys-root/${destinationsPlatform} ${dst}/sys-root

        debug "cleanup stuff in platform ${destinationsPlatform}"

        case ${destinationsPlatform} in
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

copyDocumentation() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dstDirectory=${workspace}/upload/docs
    mkdir -p ${dstDirectory}

    info "copy docs..."

    # TODO: demx2fk3 2014-04-01 implement this, fix in src-fsmpsl and src-psl is needed

    return
}

getPlatformFromDirectory() {
    local directory=$1
    baseName=$(basename ${directory})
    directoryPlatform=$(cut -d- -f3 <<< ${baseName})
    destinationsPlatform=${platformMap["${directoryPlatform}"]}
    echo ${destinationsPlatform}
    return
}

mustHavePlatformFromDirectory() {
    local directory=$1
    local platform=$2
    if [[ ! ${platform} ]] ; then
        error "can not found map for platform ${directory}"
        exit 1
    fi
    return
}

return 0

