#!/bin/bash
## @file  uc_klocwork.sh
#  @brief usecase build and upload klocwork

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

# ------------------------------------------------------------------
# settings for klocwork
# ------------------------------------------------------------------
# see also file.cfg
#
# PYTHON_HOME=/opt/python/linux64/ix86/python_3.2
#
# kw_port=8080
# kw_licence_port=27018
# kw_licence_host=eseelic050.emea.nsn-net.net
# KW_HOST=ulkloc.nsn-net.net
# KW_HOME=/home/kwbts01/kw-server
# BLD_TOOL=/build/home/SC_LFS/bldtools/bin/build
#
# name
# ULKLOC
# KLOCWORK_HOME
# /home/kwbts01/kw-server
# PROJECT_HOST
# ulkloc.nsn-net.net
# PROJECT_PORT
# 8080
# LICENCE_HOST
# eseelic050.emea.nsn-net.net
# LICENCE_PORT
# 27018
# ------------------------------------------------------------------
# jenkins job names
# LFS_CI_-_trunk_-_KlocworkBuild_-_FSM-r2_-_PS_LFS_DDALFSMR2
# LFS_CI_-_trunk_-_KlocworkBuild_-_FSM-r3_-_PS_LFS_DDAL
# 
# * jobs are build after successful build job
# * job is not blocking for the build
# ------------------------------------------------------------------

## @fn      ci_job_klocwork_build()
#  @brief   build and create statistics for klocwork
#  @param   <none>
#  @return  <none>
ci_job_klocwork_build() {
    requiredParameters WORKSPACE BUILD_ID

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local build="${workspace}/bldtools/bld-buildtools-common/results/bin/build NOAUTOBUILD=1"

    local kw_port=$(getConfig LFS_CI_uc_klocwork_port)
    mustHaveValue "${kw_port}" "klocwork port"

    local kw_host=$(getConfig LFS_CI_uc_klocwork_hostname)
    mustHaveValue "${kw_host}" "klocwork host"

    local kw_licence_port=$(getConfig LFS_CI_uc_klocwork_licence_port)
    mustHaveValue "${kw_licence_port}" "klocwork licence port"

    local kw_licence_host=$(getConfig LFS_CI_uc_klocwork_licence_host)
    mustHaveValue "${kw_licence_host}" "klocwork licence host"

    local kw_project=$(getTargetBoardName)
    mustHaveValue "${kw_project}" "klocwork project"

    local kw_inject=$(getConfig  LFS_CI_uc_klocwork_cmd_kwinject)   # ${KW_HOME}/bin/kwinject
    mustHaveValue "${kw_inject}" "klocwork cmd kwinject"

    local kw_admin=$(getConfig   LFS_CI_uc_klocwork_cmd_kwadmin)    # ${KW_HOME}/bin/kwadmin
    mustHaveValue "${kw_admin}" "klocwork cmd kwadmin"

    local kw_buildProject=$(getConfig LFS_CI_uc_klocwork_cmd_kwbuildproject) # ${KW_HOME}/bin/kwbuildproject
    mustHaveValue "${kw_buildProject}" "klocwork build project"

    local kw_url="--url $(getConfig LFS_CI_uc_klocwork_url)"        # https://${KW_HOST}:${kw_port}"
    mustHaveValue "${kw_url}" "klocwork url"

    local kw_template=$(getConfig LFS_CI_uc_klocwork_template)           # ${WORKSPACE}/kwinject.tpl
    mustHaveValue "${kw_template}" "klocwork template"
    
    local kw_tables=$(getConfig LFS_CI_uc_klocwork_tables)          # kloTables
    mustHaveValue "${kw_tables}" "klocwork tables"

    local kw_psroot=${workspace}
    mustHaveValue "${kw_psroot}" "klocwork psroot"

    local architectures=$(getConfig LFS_CI_uc_klocwork_architectures) # " mips64-octeon-linux-gnu- mips64-octeon2-linux-gnu- powerpc-e500-linux-gnu- i686-pc-linux-gnu- "
    mustHaveValue "${architectures}" "architectures"

    local reportPythonScript=$(getConfig LFS_CI_uc_klocwork_report_python_script)
    mustHaveValue "${reportPythonScript}" "python report script"

    local pythonHome=$(getConfig LFS_CI_uc_klocwork_python_home)
    mustHaveValue "${pythonHome}" "python home"


    local kw_flags=
    for crossCompiler in ${architectures}; do
        kw_flags="${kw_flags} -P ${crossCompiler}gcc=gnu -P ${crossCompiler}g++=gnu"
    done

    # we need the noglob here, because of the --ignore-files pattern.
    # with quotes, it does not work. so do not quote the **/*build/**/* in '' or in ""
    set -o noglob

    kw_flags="${kw_flags} --ignore-files **/*build/**/*,**/*build/*,**/.sconf_temp/* --variable kwpsroot=${kw_psroot}"

    info "using klocwork project ${kw_project}"
    # get this via src-proejct
    case "${kw_project}" in
        *_DDAL)      BLDCMD="${build} -C src-rfs fct; ${build} -C src-fsmddal fct"                         ;;
        *_DDG)       BLDCMD="${build} -C src-bos fct; ${build} -C src-fsmddg fct; ${build} -C src-ddg fct" ;;
        *_DDALFSMR2) BLDCMD="${build} -C src-ddal fcmd; ${build} -C src-ddal fspc"                         ;;
        *)           fatal "unknown klocwork project"                                                      ;;
    esac

    createOrUpdateWorkspace --allowUpdate

    if [[ -e ${kw_template} ]] ; then
        kw_flags="${kw_flags} --update"
    else
        kw_flags="${kw_flags}"
    fi

    debug "change directory to ${workspace}"
    execute cd ${workspace}

    # create build specification template
    info "running klocwork inject command..."
    execute ${kw_inject} ${kw_flags} -o ${kw_template} bash -c "${BLDCMD}"

    # import klocwork build specification template
    info "running klocwork import-config command..."
    execute ${kw_admin} ${kw_url} import-config ${kw_project} ${kw_template}

    # build klocwork project
    info "running klocwork buildproject command..."
    execute ${kw_buildProject} ${kw_url}/${kw_project}                         \
                                    --license-host ${kw_licence_host}          \
                                    --license-port ${kw_licence_port}          \
                                    --replace-path ${kw_psroot}/src-=src-      \
                                    --buildspec-variable kwpsroot=${kw_psroot} \
                                    --incremental                              \
                                    --project ${kw_project}                    \
                                    --tables-directory ${kw_tables} ${kw_template}

    # upload build report
    local canUploadBuild=$(getConfig LFS_CI_uc_klocwork_can_upload_builds)
    if [[ ${canUploadBuild} ]] ; then
        execute ${kw_admin} ${kw_url} load ${kw_project} ${kw_tables} --name build_ci_${BUILD_ID}
    else
        warning "klocwork load is disabled via config"
    fi

    # create XML report
    svnExport ${reportPythonScript}
    LD_LIBRARY_PATH=${pythonHome}/lib                                \
                    execute -n ${pythonHome}/bin/python getreport.py \
                                    ${kw_host}                       \
                                    ${kw_port}                       \
                                    ${kw_project}                    \
                                    LAST > ${WORKSPACE}/klocwork_result.xml

    # cleanup old build reports
    local canDeleteBuilds=$(getConfig LFS_CI_uc_klocwork_can_delete_builds)
    if [[ ${canDeleteBuilds} ]] ; then
        local buildsList=$(createTempFile)
        execute -n ${kw_admin} ${kw_url} list-builds ${kw_project} | sort -u > ${buildsList}
        execute sed -ine "/^\(Bld\|Build\|Rev\|build_ci\)/ {17,$ p}" ${buildsList}

        rawDebug ${buildsList}
        while read build ; do 
            info "remove build ${kw_project} / ${build}"
            execute -i ${kw_admin} ${kw_url} delete-build ${kw_project} "${build}"
        done < ${buildsList}
    else
        warning "klocwork delete build is disabled via config"
    fi

    return
}
