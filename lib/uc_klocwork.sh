# settings for klocwork
# PYTHON_HOME=/opt/python/linux64/ix86/python_3.2

# KW_PORT=8080
# KW_LICENCE_PORT=27018
# KW_LICENCE_HOST=eseelic050.emea.nsn-net.net
# KW_HOST=ulkloc.nsn-net.net
# KW_HOME=/home/kwbts01/kw-server
# BLD_TOOL=/build/home/SC_LFS/bldtools/bin/build

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

ci_job_klocwork_build() {

    requiredParameters WORKSPACE JOB_NAME BUILD_ID

    set -o noglob

    local BUILD="bldtools/bld-buildtools-common/results/bin/build NOAUTOBUILD=1"

    local location=$(getLocationName)
    mustHaveValue "${location}" "location name"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local KWPROJECT=$(getConfig LFS_CI_uc_klocwork_project_name)
    local KWINJECT=${KW_HOME}/bin/kwinject
    local KWADMIN=${KW_HOME}/bin/kwadmin
    local KWBUILDPROJECT=${KW_HOME}/bin/kwbuildproject
    local KWURL="--url https://${KW_HOST}:${KW_PORT}"
    local KWTPL=${WORKSPACE}/kwinject.tpl
    local KWTABLES=kloTables
    local KWPSROOT=$(readlink -f ${WORKSPACE})

    if [ -n "${KW_PROJECT}" ]; then
        KWPROJECT=${KW_PROJECT}
    else
        KWPROJECT=PS_LFS_${JOB_NAME##*_}
    fi

    ARCHS="
        mips64-octeon-linux-gnu-
        mips64-octeon2-linux-gnu-
        powerpc-e500-linux-gnu-
        i686-pc-linux-gnu-
    "

    for CROSS_COMPILE in ${ARCHS}; do
        KWFLAGS="${KWFLAGS} -P ${CROSS_COMPILE}gcc=gnu -P ${CROSS_COMPILE}g++=gnu"
    done
    KWFLAGS="${KWFLAGS} --ignore-files **/*build/**/*,**/*build/* --variable kwpsroot=${KWPSROOT}"

    # get this via src-proejct
    case "${KWPROJECT}" in
    *_DDAL)      BLDSRC="src-rfs src-fsmddal"; 
                 BLDCMD="${BUILD} -C src-rfs fct; ${BUILD} -C src-fsmddal fct"
    ;;
    *_DDG)       BLDSRC="src-fsmbos src-fsmddg src-ddg";  
                 BLDCMD="${BUILD} -C src-bos fct; ${BUILD} -C src-fsmddg fct; ${BUILD} -C src-ddg fct"
    ;;
    *_DDALFSMR2) BLDSRC=src-ddal;    
                 BLDCMD="${BUILD} -C ${BLDSRC} fcmd; ${BUILD} -C ${BLDSRC} fspc"
    ;;
    *) exit -1;;
    esac

    createOrUpdateWorkspace --allowUpdate

    if [[ -e ${KWTPL} ]] ; then
        KWFLAGS="--update"
    else
        KWFLAGS=""
    fi

    # create build specification template
    execute ${KWINJECT} ${KWFLAGS} -o ${KWTPL} bash -c "${BLDCMD}"

    # upload klocwork build specification template
    execute ${KWADMIN} ${KWURL} import-config ${KWPROJECT} ${KWTPL}

    # build klocwork project
    execute ${KWBUILDPROJECT} ${KWURL}/${KWPROJECT}                           \
                                    --license-host ${KW_LICENCE_HOST}         \
                                    --license-port ${KW_LICENCE_PORT}         \
                                    --replace-path ${KWPSROOT}/src-=src-      \
                                    --buildspec-variable kwpsroot=${KWPSROOT} \
                                    --incremental                             \
                                    --project ${KWPROJECT}                    \
                                    --tables-directory ${KWTABLES} ${KWTPL}

    # upload build report
    local canUploadBuild=$(getConfig LFS_CI_uc_klocwork_can_upload_builds)
    if [[ -z ${canUploadBuild} ]] ; then
        execute ${KWADMIN} ${KWURL} load ${KWPROJECT} ${KWTABLES} --name build_ci_${BUILD_ID}
    else
        warning "klocwork load is disabled via config"
    fi

    # create XML report
    local reportPythonScript=$(getConfig LFS_CI_uc_klcwork_report_python_script)
    svnExport ${reportPythonScript}
    LD_LIBRARY_PATH=${PYTHON_HOME}/lib \
                    execute ${PYTHON_HOME}/bin/python getreport.py \
                            ${KW_HOST} \
                            ${KW_PORT} \
                            ${KWPROJECT} \
                            LAST > klocwork_result.xml


    # cleanup old build reports
    local canDeleteBuilds=$(getConfig LFS_CI_uc_klocwork_can_delete_builds)
    if [[ -z ${canDeleteBuilds} ]] ; then
        local buildsList=$(createTempFile)
        execute -n ${KWADMIN} ${KWURL} list-builds ${KWPROJECT} > ${buildsList}
        execute sed -ine "/^\(Bld\|Build\|Rev\|build_ci\)/ {17,$ p}" ${buildsList}

        rawDebug ${buildsList}
        while read build ; do 
            info "remove build ${KWPROJECT} / ${build}"
            ${KWADMIN} ${KWURL} delete-build ${KWPROJECT} "${buil}"
        done < ${buildsList}
    else
        warning "klocwork delete build is disabled via config"
    fi

    return
}
