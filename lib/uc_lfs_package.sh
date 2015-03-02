#!/bin/bash
## @file  uc_lfs_package.sh
#  @brief usecase lfs packing

LFS_CI_SOURCE_uc_lfs_package='$Id$'

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_package}   ]] && source ${LFS_CI_ROOT}/lib/package.sh
[[ -z ${LFS_CI_SOURCE_database}  ]] && source ${LFS_CI_ROOT}/lib/database.sh

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
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD JOB_NAME BUILD_NUMBER

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    debug "workspace is ${workspace}"

    local requiredArtifacts=$(getConfig LFS_CI_UC_package_required_artifacts)
    copyArtifactsToWorkspace "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "${requiredArtifacts}"

    mustHaveNextCiLabelName
    local label=$(getNextReleaseLabel)

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"

    copyAddons
    copyVersionFile
    copyDocumentation
    copyPlatform
    copyArchs
    copySysroot
    copyFactoryZip
    copyGenericBuildResults

    # there are some symlinks in other directories, which are broken at the moment
    # so we are just removing / fixing symlinks in sys-root
    removeBrokenSymlinks ${workspace}/upload/sys-root/

    execute rm -rf ${workspace}/upload/psl_merge

    # creates a file under doc/ with all delivered files of a LFS OS release
    createOsFileList

    copyReleaseCandidateToShare

    return
}

## @fn      copyGenericBuildResults()
#  @brief   copy the build results from the bld/bld-*-*/results/psl directory
#           in the regarding structure of the build
#  @details see also the proposal from Reiner Huober about the cleanup of psl
#  @param   <none>
#  @return  <none>
copyGenericBuildResults() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dst=${workspace}/upload/sys-root/

    for bldDirectory in ${workspace}/bld/bld-*-*/results/psl/sys-root ; do
        [[ -d ${bldDirectory} ]] || continue
        info "copy generic build results from ${bldDirectory} to ${dst}"
        execute rsync -av --exclude=.svn ${bldDirectory}/ ${dst}/
    done

    local dst=${workspace}/upload/platforms/
    for bldDirectory in ${workspace}/bld/bld-*-*/results/psl/platforms ; do
        [[ -d ${bldDirectory} ]] || continue
        info "copy generic build results from ${bldDirectory} to ${dst}"
        execute rsync -av --exclude=rootfs.d --exclude=.svn ${bldDirectory}/ ${dst}/
    done
    return
}

## @fn      copyAddons()
#  @brief   handle the addons, copy the addons from the results directory into the delivery structure
#  @details function checks for bld-*psl*-*/results/addons directory and copy the content into the
#           regarding delivery directory
#  @param   <none>
#  @return  <none>
copyAddons() {

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    # TODO: demx2fk3 2014-07-02 remove this - do it in a different way
    rm -rf ${workspace}/bld/bld-psl-rootfs

    for bldDirectory in ${workspace}/bld/bld-*psl*-* ; do
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

        if [[ "${destinationsPlatform}" == "powerpc-e500-linux-gnu" ]] ; then
            info "removing tgz addons from powerpc-e500-linux-gnu"
            execute find ${dstDirectory} -name \*.tgz -type f -exec rm -f {} \;
        fi
    done

    return
}

## @fn      copyArchs()
#  @brief   handle the archs directory
#  @details C
#  @param   <none>
#  @return  <none>
copyArchs() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName


    for bldDirectory in ${workspace}/bld/bld-*psl*-* ; do
        [[ -d ${bldDirectory} ]] || continue

        local destinationsArchitecture=$(getArchitectureFromDirectory ${bldDirectory})
        info "handling archs for ${destinationsArchitecture}"
        # TODO: demx2fk3 2014-07-21 fixme
        # mustHavePlatformFromDirectory ${bldDirectory} ${destinationsArchitecture} 
        local dst=${workspace}/upload/archs/${destinationsArchitecture}
        execute mkdir -p ${dst}

        # TODO: demx2fk3 2014-07-21 fixme - what's about sdk without 3
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

    for bldDirectory in ${workspace}/bld/bld-*psl*-* ; do

        [[ -d ${bldDirectory} ]] || continue

        local destinationsArchitecture=$(getArchitectureFromDirectory ${bldDirectory})
        mustHavePlatformFromDirectory ${bldDirectory} ${destinationsArchitecture} 

        local platform=$(getPlatformFromDirectory ${bldDirectory})
        mustHaveValue "${platform}" "platform from directory"

        info "copy sys-root for ${destinationsArchitecture}"

        local dst=${workspace}/upload/sys-root/${destinationsArchitecture}
        execute mkdir -p ${dst}/doc

        for file in ${workspace}/bld/bld-fsmddal-doc/results/doc/{FSM,}DDAL.pdf ; do
            if [[ -f ${file} ]] ; then
                info "copy ${file} to documentation directory in sysroot"
                execute cp ${file} ${dst}/doc/
            fi
        done

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
        local sysroot_tgz
        case ${platform} in
            lrc-*)   sysroot_tgz=${workspace}/bld/bld-rfs-lcpa/results/sysroot.tar.gz ;;
#            fsm4_*)  sysroot_tgz=${workspace}/bld/bld-rfs-arm/results/sysroot.tar.gz  ;;
            qemu_64) sysroot_tgz=${bldDirectory}/results/rfs.init_sys-root.tar.gz  
                     [[ $(getBranchName) =~ "LRC" ]] && \
                     sysroot_tgz=${workspace}/bld/bld-rfs-qemu_x86_64/results/sysroot.tar.gz ;;
            *)       sysroot_tgz=${bldDirectory}/results/rfs.init_sys-root.tar.gz     ;;
        esac

        info "using sysroot for ${platform} ${sysroot_tgz}"

        if [[ -e ${sysroot_tgz} ]] ; then
            debug "untar ${sysroot_tgz}"
            # TODO: demx2fk3 2014-04-07 expand the short parameter names
            execute tar -xzf ${sysroot_tgz} -C ${dst}
        else
            error "missing ${sysroot_tgz}, else path not implemented"
            exit 1
        fi

        # handling libddal stuff            
        case ${destinationsArchitecture} in
            i686-pc-linux-gnu)
                execute tar -xvz -C ${dst}/usr --strip-components=1 -f ${workspace}/bld/bld-ddal-qemu_i386/results/include/ifddal.tgz
                execute ln -sf libDDAL.so.qemu_i386 ${dst}/usr/lib/libDDAL.so
            ;;
            powerpc-e500-linux-gnu)
                # execute tar -xvz -C ${dst}/usr --strip-components=1 -f ${workspace}/bld/bld-ddal-fcmd/results/include/ifddal.tgz
                execute ln -sf libDDAL.so.fcmd ${dst}/usr/lib/libDDAL_fcmd.so
                execute ln -sf libDDAL.so.fcmd ${dst}/usr/lib/libDDAL.so
                execute ln -sf libDDAL.so.fcmd ${dst}/usr/lib/libDDAL_fspc.so
            ;;
            x86_64-pc-linux-gnu)
                # execute tar -xvz -C ${dst}/usr --strip-components=1 -f ${workspace}/bld/bld-fsmddal-qemu_x86_64/results/include/fsmifdd.tgz
                # execute ln -sf libFSMDDAL.so.qemu_x86_64 ${dst}/usr/lib/libFSMDDAL_qemu_x86_64.so
                # execute ln -sf libFSMDDAL.so.qemu_x86_64 ${dst}/usr/lib/libFSMDDAL.so
                [[ $(getBranchName) =~ "LRC" ]] && \
                    execute tar -xv -C ${dst}/usr --strip-components=1 -f ${workspace}/bld/bld-lrcpsl-lcpa/results/lrcddal/fsmifdd.tgz
                [[ $(getBranchName) =~ "LRC" ]] && \
                    execute rm -f ${dst}/usr/lib/libFSMDDAL* 
            ;;
            mips64-octeon2-linux-gnu)
               # execute tar -xvz -C ${dst}/usr --strip-components=1 -f ${workspace}/bld/bld-fsmddal-fct/results/include/fsmifdd.tgz
               # execute ln -sf libFSMDDAL.so.fct ${dst}/usr/lib64/libFSMDDAL_fsm3_octeon2.so
               # execute ln -sf libFSMDDAL.so.fct ${dst}/usr/lib64/libFSMDDAL.so
               # execute ln -sf libFSMDDAL.so.fct ${dst}/usr/lib64/libDDAL.so
                [[ $(getBranchName) =~ "LRC" ]] && \
                    execute tar -xv -C ${dst}/usr --strip-components=1 -f ${workspace}/bld/bld-lrcpsl-lcpa/results/lrcddal/fsmifdd.tgz
                [[ $(getBranchName) =~ "LRC" ]] && \
                    execute mv ${dst}/usr/lib/libFSMDDAL* ${dst}/usr/lib64/
            ;;
            mips64-octeon-linux-gnu)
                execute tar -xvz -C ${dst}/usr --strip-components=1 -f ${workspace}/bld/bld-fsmddal-fct/results/include/fsmifdd.tgz
                execute ln -sf libFSMDDAL.so.fct ${dst}/usr/lib64/libFSMDDAL_fsm3_octeon.so
                execute ln -sf libFSMDDAL.so.fct ${dst}/usr/lib64/libFSMDDAL.so
            ;;
            arm-cortexa15-linux-gnueabihf)
                execute tar -xvz -C ${dst}/usr --strip-components=1 -f ${workspace}/bld/bld-fsmddal-fsm4_arm/results/include/fsmifdd.tgz

                execute ln -sf libFSMDDAL.so.fsm4_arm ${dst}/usr/lib/libFSMDDAL.so
                execute ln -sf libFSMDDAL.so.fsm4_arm ${dst}/usr/lib/libFSMDDAL_fsm4_arm.so
                execute ln -sf libFSMDDAL.so.fsm4_arm ${dst}/usr/lib/libDDAL.so

                if [[ -e ${dst}/usr/lib/libFSMDDAL.so.fsm35_k2 ]] ; then
                    warning "renaming libFSMDDAL.so.fsm35_k2 to libFSMDDAL.so.fsm4_arm, please fix this in src-fsmddal"
                    execute mv ${dst}/usr/lib/libFSMDDAL.so.fsm35_k2 ${dst}/usr/lib/libFSMDDAL.so.fsm4_arm
                fi
            ;;
            *)
                error "architecture ${destinationsArchitecture} not supported"
                exit 1
            ;;
        esac            

    done

    if [[ $(getBranchName) =~ "LRC" ]] ; then
        for bldDirectory in ${workspace}/bld/bld-*-*/ ; do
            [[ -d ${bldDirectory}                   ]] || continue
            [[ -d ${bldDirectory}/results/sys-root/ ]] || continue

            local destinationsArchitecture=$(getArchitectureFromDirectory ${bldDirectory})
            mustHavePlatformFromDirectory ${bldDirectory} ${destinationsArchitecture} 

            local platform=$(getPlatformFromDirectory ${bldDirectory})
            mustHaveValue "${platform}" "platform from directory from ${bldDirectory}"

            info "copy sys-root for ${destinationsArchitecture} from ${bldDirectory}"
            local dst=${workspace}/upload/
            execute rsync -av --exclude=.svn ${bldDirectory}/results/sys-root/ ${dst}/sys-root/
        done
    fi

    return
}

## @fn      copyFactoryZip()
#  @brief   create the factory.zip file out of platforms/fsm3_octeon2
#  @warning side effect: change the current directory (and change it back!)
#  @param   <none>
#  @return  <none>
copyFactoryZip() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    # TODO: demx2fk3 2014-05-27 fixme
    for dst in ${workspace}/upload/platforms/fsm3_octeon2 \
               ${workspace}/upload/platforms/fsm4_axm     \
               ${workspace}/upload/platforms/fsm4_k2
    do
        if [[ -d ${dst} ]] ; then
            execute cd ${dst}
            execute zip -r factory.zip factory
            execute cd $OLDPWD
        fi
    done

    return
}

## @fn      copyPlatform()
#  @brief   handle the platform directory in the delivery structure
#  @details 
#  @param   <none>
#  @return  <none>
copyPlatform() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    for bldDirectory in ${workspace}/bld/bld-*psl*-* ; do
        [[ -d ${bldDirectory}         ]] || continue
        [[ -d ${bldDirectory}/results ]] || continue

        local platform=$(getPlatformFromDirectory ${bldDirectory})
        mustHavePlatformFromDirectory ${bldDirectory} ${platform}

        local architecture=$(getArchitectureFromDirectory ${bldDirectory})
        mustHaveArchitectureFromDirectory ${bldDirectory} ${architecture}

        local dst=${workspace}/upload/platforms/${platform}
        execute mkdir -p ${dst}

        info "copy platform for ${platform} / ${architecture} ..."

        # TODO: demx2fk3 2014-04-07 expand the short parameter names
        if [[ $(getBranchName) =~ "LRC" ]] ; then
            case ${platform} in 
                qemu_64)
                    execute rsync -avr --exclude=.svn --exclude=addons --exclude=sys-root --exclude=rfs.init_sys-root.tar.gz ${bldDirectory}/results/. ${workspace}/upload/
                    execute mv -f ${workspace}/upload/platforms/qemu_x86_64/* ${dst}
                    execute rmdir ${workspace}/upload/platforms/qemu_x86_64                                                                                 

                ;;
                lrc-octeon2)
                    execute rsync -avr --exclude=addons --exclude=sys-root --exclude=rfs.init_sys-root.tar.gz ${bldDirectory}/results/. ${workspace}/upload/
                ;;
            esac
        else
            execute rsync -avr --exclude=addons --exclude=sys-root --exclude=rfs.init_sys-root.tar.gz ${bldDirectory}/results/. ${dst}
        fi


        debug "symlink addons"
        execute ln -sf ../../addons/${architecture} ${dst}/addons

        debug "symlinks sys-root"
        execute ln -sf ../../sys-root/${architecture} ${dst}/sys-root

        debug "cleanup stuff in platform ${platform}"

        case ${platform} in
            qemu)        : ;;  # no op
            fcmd | fspc) : ;;  # no op
            qemu_64)
                    if [[ $(getBranchName) =~ "LRC" ]] ; then
                        info "copy platforms/qemu_x86_64/rfs.init_sys-root.tar.gz to ${dst}"
                        execute cp ${bldDirectory}/results/platforms/qemu_x86_64/rfs.init_sys-root.tar.gz ${dst}
                    else
                        mkdir ${dst}/devel
                        for file in ${dst}/config     \
                                    ${dst}/System.map \
                                    ${dst}/vmlinux.*  \
                                    ${dst}/uImage.nfs
                        do
                            [[ -f ${file} ]] || continue
                            execute mv -f ${file} ${dst}/devel
                        done
                    fi                            
            ;;
            fsm3_octeon2|fsm35_k2|fsm35_axm|fsm4_axm|fsm4_k2|keystone2|axm)
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

        if [[ -d ${bldDirectory}/results/psl_merge/ ]] ; then
            info "adding psl_merge from ${bldDirectory}"
            execute rsync -avr ${bldDirectory}/results/psl_merge/. ${workspace}/upload/
        fi

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

    info "copy verson control file..."
    for file in ${workspace}/bld/bld-fsmpsl-fct/results/doc/versions/version_control.xml \
                ${workspace}/bld/bld-fsmpsl-fct/results/doc/versions/ptsw_fsmr3_version_control.xml \
                ${workspace}/bld/bld-fsmpsl-fct/results/doc/versions/ptsw_fsmr4_version_control.xml \
                ${workspace}/bld/bld-fsmpsl-fct/results/doc/versions/ptsw_urec_version_control.xml
    do
        [[ -e ${file} ]] || continue
        execute cp ${file} ${dstDirectory}
        execute cp ${file} ${dstDirectory}/..
    done

    return
}

## @fn      copyDocumentation()
#  @brief   copy the documentation into the delivery structure
#  @param   <none>
#  @return  <none>
copyDocumentation() {
    requiredParameters WORKSPACE UPSTREAM_BUILD UPSTREAM_PROJECT

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dst=${workspace}/upload/doc
    execute mkdir -p ${dst}

    info "copy doc..."

    # TODO: demx2fk3 2014-04-01 implement this, fix in src-fsmpsl and src-psl is needed
    for bldDirectory in ${workspace}/bld/bld-*psl*-* ; do
        [[ -d ${bldDirectory} ]] || continue
        [[ -d ${bldDirectory}/results/doc ]] || continue
        execute rsync -av --exclude=.svn ${bldDirectory}/results/doc/. ${dst}/
    done

    for file in ${workspace}/bld/bld-fsmddal-doc/results/doc/{FSM,}DDAL.pdf ; do
        if [[ -f ${file} ]] ; then
            info "copy ${file} to documentation directory"
            execute cp ${file} ${dst}/
        fi
    done

    execute mkdir -p ${dst}/scripts/
    for file in ${workspace}/bld/bld-externalComponents-*/workdir_*.sh ; do
        [[ -f ${file} ]] || continue
        debug "copy $(basename ${file}) to documentation"
        execute cp ${file} ${dst}/scripts/
    done

    debug "copy revision state file to documentation"
    copyRevisionStateFileToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} 
    execute cp -f ${WORKSPACE}/revisions.txt ${dst}/scripts/

    return
}

## @fn      createOsFileList()
#  @brief   creates a file list file in subdir doc including all file names below os/ of a LFS OS delivery
#           This was requested by PS-SCM (Wolfgang Adlassnig), because all SC will deliver such a list.
#  @param   <none>
#  @return  <none>
createOsFileList() {
    info "create OS file list of all files delivered by LFS in subdir doc ..."
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local dst=${workspace}/upload
    execute -n find ${dst} -not -type d | sort | xargs md5sum 2>/dev/null | sed "s,${dst}/,,g" > ${dst}/doc/list_all_os_files.txt
    execute -n find ${dst} -not -type d | sort | xargs du -k  2>/dev/null | sed "s,${dst}/,,g" > ${dst}/doc/list_all_os_sizes_of_files.txt

    return
}
