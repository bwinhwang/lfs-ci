#!/bin/bash

## @file setup-sandbox.sh
## @brief setup Jenkins
## @details Setup a LFS Sandbox Jenkins on local machine by
##          using most of the data from lfs production Jenkins.
##          Use -h to geht help.
##
## Some notes:
## If you use the -h option after another option, the value/flag of
## the option specified before the -h flag is used in the help text.
## setup-sandbox.sh -h gives the following output for -t HTTP_PORT.
##     -t HTTP_PORT for Jenkins. Defaults to 8090.
## setup-sandbox.sh -t 5050 -h gives the following output for -t HTTP_PORT.
##     -t HTTP_PORT for Jenkins. Defaults to 5050.
##
## The script may not run on ulegcpmaxi and also not as user psulm.

ITSME=$(basename $0)

# Defaults
ADMIN_JOBS="false"
UBOOT="false"
DEV_VIEWS="false"
TEST_JOBS="false"
BRANCH_VIEWS="trunk"
NESTED_VIEWS=""
ROOT_VIEWS=""
DISABLE_BUILD_JOBS="true"
LRC="false"
KEEP_JENKINS_PLUGINS="false"
WORK_DIR="/var/fpwork"
LOCAL_WORK_DIR=${WORK_DIR}
CI_USER="psulm"
LRC_CI_USER="ca_lrcci"
LFS_CI_ROOT="${HOME}/lfs-ci"
SANDBOX_USER=${USER}
PURGE_SANDBOX="false"
HTTP_PORT="8090"
LFS_CI_CONFIG_FILE=""
UPDATE_JENKINS="false"
PROD_JENKINS_SERVER="lfs-ci.emea.nsn-net.net"
START_OPTION=""
JUST_START="false"
# Subdirectory within $WORK_DIR/$USER
JENKINS_DIR="lfs-jenkins" # subdirectory within $WORK_DIR/$USER
# Following jobs are copied always.
DEFAULT_JOBS="LFS_BRANCHING_-_ \
Admin_-_reserveTarget \
Admin_-_releaseTarget \
Admin_-_deployCiScripting"
# This jos are copied in case the script is started as user lfscidev.
OTHER_ADMIN_JOBS="Admin_-_backup_mysql \
Admin_-_backupJenkins \
Admin_-_cleanUpArtifactsShare \
Admin_-_cleanupS3Storage_-_lfs-developer-builds \
Admin_-_cleanupS3Storage_-_lfs-knives \
Admin_-_create_patch_release \
Admin_-_createLfsBaselineListFromEcl \
Admin_-_enable_jenkins_job \
Admin_-_recreate_branches_cfg_from_database \
Admin_-_repairTarget \
Admin_-_restore_mysql \
Admin_-_svn_clone_restore_from_master \
Admin_-_svn_clone_sync_BTS_SC_LFS \
Admin_-_updateLocationsTextFile"
TRUNK_JOBS="LFS_CI_-_trunk_-_ LFS_Prod_-_trunk_-_ PKGPOOL_-_trunk_-_"

usage() {
cat << EOF

    Script in order to setup a LFS CI Jenkins on local machine. Such a installation  is
    also known as LFS CI Sandbox.

    IMPORTANT:

        - This script is interactive!

        - Before or after running this script you probably might run setup-database.sh.

    Jenkins will be installed into directory \${LOCAL_WORK_DIR}/$USER/${JENKINS_DIR}/home. This
    can be overridden by using -w LOCAL_WORK_DIR. CI scripting will be cloned to \${LFS_CI_ROOT}
    pointing to branch development in which \${LFS_CI_ROOT} defaults to \${USER}/lfs-ci but can
    be overriden with the -s option.

    Job and view configuration are copied from Jenkins production server. Per default all *_Build$ Jobs
    will be disabled within the Sandbox. If you want them to be enabled use the -e flag.

    After the script has been finished check the system settings of the new LFS CI Sandbox.

    Example: $ITSME -k -u -x -l -f /home/lfscidev/lfs-ci/etc/development.cfg

             Create UBOOT (-u), DEV/* (-x), ADMIN and trunk (as per default) and LRC (-l) views.
             Disable all *_Build$ jobs (-e is missing). Also copy all Test-* jobs (-k).

    Options and Flags:
        -f Complete path of CI scripting config file.
        -b Comma separated list of BRANCHES to be copied from LFS CI (not LRC branches). Defaults to ${BRANCH_VIEWS}.
           If you specify -b on command line and you want to create trunk as well, trunk must be in the list of
           branches to be copied (eg -b trunk,FB1506,MD11504).
        -n Comma separated list of nested view that should be created in Sandbox. DEV/* views can be specified via -x.
        -r Comma separated list of root views (Jenkins top level tabs) that should be created within Sandbox. Eg. 1506,1405.
           The ADMIN view is created per default and the UBOOT view can be created by adding -u flag.
        -w Specify \$LOCAL_WORK_DIR directory for Jenkins installation. Defaults to ${LOCAL_WORK_DIR}.
        -i LFS CI user. Defaults to ${CI_USER}.
        -c LFS LRC CI user. Defaults to ${LRC_CI_USER}.
        -s Root directory of LFS CI scripting. Defaults to ${LFS_CI_ROOT}.
        -d Delete local Sandbox installation. You can use -w and -s if you want to delete a non standard installation.
        -t HTTP_PORT for Jenkins. Defaults to ${HTTP_PORT}.
        -g <sysv> If -g is omitted, Jenkins is started via nohup in the background.
                  sysv: Start Jenkins via the script /etc/init.d/jenkins.
        -e (flag) Disable all *_Build$ jobs in Sandbox. Default is to disable all *_Build$ jobs (missing -e).
        -l (flag) Create LRC view in Sandbox. Default is don't create LRC in Sandbox.
        -p (flag) Keep Jenkins plugins from an existing Sandbox installation. Defaults is false (missing -p).
        -o (flag) Just start Jenkins (don't do anything else). Default is false (missing -o). Additionally you can also use -g.
        -j (flag) Update Sandbox Jenkins in ${LOCAL_WORK_DIR}. Additionally the options -w -b -n -x -u -a and -l can be used.
                  Jenkins plugins and jobs will be updated from Jenkins production server. After this reload Jenkins config
                  from disk or start/restart Sandbox. Note: No views are created by using -j. This option is for updating jobs
                  and plugins.
        -x (flag) Create the DEV/* views within Sandbox and copy the related jobs. Additional nested views (eg. 1508)
                  can be created via -n parameter. Default is not creating DEV/* nested views.
        -u (flag) Create the UBOOT view and copy the related jobs. Default is not creating UBOOT.
        -a (flag) Copy the Admin_-_* jobs. Default is not coping the Admin_-_* jobs execpt the mandatroy
                  jobs ${DEFAULT_JOBS}.
        -k (flag) Copy the "Test-*" jobs. Default is not coping "Test-*" jobs.
        -h Get help

    Examples:

        Standard Sandbox installation. (Copy trunk jobs, create trunk view, create ADMIN view and copy
        jobs ${DEFAULT_JOBS}):

            ${ITSME} -f <path-to-development.cfg>

        Create LRC (-l), use existing Jenkins plugins (-p) and start Sandbox on port 9090 (-t):
            ${ITSME} -l -p -t 9090 -f <path-to-development.cfg>

        Just start Jenkins(-o):
            ${ITSME} -o -f ~/lfs-ci/etc/development.cfg

        Update trunk jobs and ${DEFAULT_JOBS} in Sandbox:
            ${ITSME} -j

        Remove standard Sandbox:
            ${ITSME} -d

        Remove non standard Sandbox:
            ${ITSME} -d -w ... -s ...

EOF
    exit 0
}

pre_checks() {
    which java > /dev/null || { echo "java is needed"; exit 1; }
    which curl > /dev/null || { echo "curl is needed"; exit 1; }
    which rsync > /dev/null || { echo "rsync is needed"; exit 1; }
}

## @fn      pre_actions()
#  @brief   check needed requirements
#  @return  <none>
pre_actions() {
    if [[ $(hostname) =~ .*maxi.* ]]; then
        echo "ERROR: This script may not run on $(hostname)."
        exit 1
    fi

    if [[ ${USER} == psulm ]]; then
        echo "ERROR: This script may not run as user psulm."
        exit 2
    fi

    if [[ ${UPDATE_JENKINS} == false && $(ps aux | grep java | grep -v slave.jar | grep jenkins) ]]; then
        echo "ERROR: Jenkins is still running."
        exit 3
    fi

    if [[ -d ${LOCAL_WORK_DIR} && ! -w ${LOCAL_WORK_DIR} ]]; then
        echo "ERROR: Ensure that ${LOCAL_WORK_DIR} is writable for user ${SANDBOX_USER}."
        exit 4
    fi

    if [[ "${KEEP_JENKINS_PLUGINS}" == "true" && ! -d ${JENKINS_PLUGINS} ]]; then
        echo "ERROR: -p makes no sense because there is no ${JENKINS_PLUGINS}"
        exit 5
    fi

    if [[ ! -r ${LFS_CI_CONFIG_FILE} && ${PURGE_SANDBOX} == false && ${UPDATE_JENKINS} == false ]]; then
        echo "ERROR: Can't read config file ${LFS_CI_CONFIG_FILE}."
        exit 6
    fi
}

adjust_args() {
    if [[ ${ROOT_VIEWS} ]]; then
        ROOT_VIEWS=${ROOT_VIEWS},ADMIN
    else
        ROOT_VIEWS=ADMIN
    fi

    if [[ ${UBOOT} == true ]]; then
        if [[ ${ROOT_VIEWS} ]]; then
            ROOT_VIEWS=${ROOT_VIEWS},UBOOT
        else
            ROOT_VIEWS=UBOOT
        fi
    fi

    if [[ ${DEV_VIEWS} == true ]]; then
        if [[ ${NESTED_VIEWS} ]]; then
            NESTED_VIEWS=${NESTED_VIEWS},DEV/Developer_Build,DEV/Knife_alpha
        else
            NESTED_VIEWS=DEV/Developer_Build,DEV/Knife_alpha
        fi
    fi
}

_git_clone() {
    echo "    Clone git repo ${GIT_URL} into ${LFS_CI_ROOT}"
    [[ -d ${LFS_CI_ROOT} ]] && rm -rf ${LFS_CI_ROOT}
    cd ${HOME}
    git clone ${GIT_URL}
    cd ${LFS_CI_ROOT}
    echo "    Checkout branch development"
    git checkout development
}

## @fn      git_stuff()
#  @brief   clone or pull lfs-ci git repository in $HOME/lfs-ci
#  @details If \$LFS_CI_ROOT already exists, git pull is invoked on
#           branch development. Otherwise lfs-ci.git is cloned from
#           git server. After cloning branch development is checked out.
#  @return  <none>
git_stuff() {
    echo "Git stuff..."
    if [[ -d ${LFS_CI_ROOT} ]]; then
        echo -e "    HELP ME:\n    ${LFS_CI_ROOT} already exists. What shall I do (type 1, 2 or 3)?:\n\
        1 Don't toch existing ${LFS_CI_ROOT}.\n\
        2 Change into ${LFS_CI_ROOT} and pull branch \"development\".
        3 Remove existing ${LFS_CI_ROOT}, clone CI scripting into ${LFS_CI_ROOT} and checkout branch \"developement\"."
        read ans
        if [[ ${ans} -eq 1 ]]; then
            echo "    Didn't touch ${LFS_CI_ROOT}."
            return
        elif [[ ${ans} -eq 2 ]]; then
            echo "    Checkout branch development"
            cd ${LFS_CI_ROOT}
            git checkout development
            echo "    Pulling branch development"
            git pull origin development
            cd -
        elif [[ ${ans} -eq 3 ]]; then
            _git_clone
        else
            echo "    Invalid answer. Only 1, 2 or 3 is allowed."
            exit 1
        fi
    else
        _git_clone
    fi
}

## @fn      jenkins_prepare_sandbox()
#  @brief   create jenkins home from scratch.
#  @return  <none>
jenkins_prepare_sandbox() {
    echo "Jenkins stuff..."
    if [[ -d ${LOCAL_WORK_DIR}/${SANDBOX_USER}/${JENKINS_DIR} ]]; then 
        echo "    Remove dir ${LOCAL_WORK_DIR}/${SANDBOX_USER}/${JENKINS_DIR}"
        rm -rf ${LOCAL_WORK_DIR}/${SANDBOX_USER}/${JENKINS_DIR}
    fi
    echo "    Create dir ${JENKINS_HOME}/jobs"
    mkdir -p ${JENKINS_HOME}/jobs
}

## @fn      jenkins_prepare_sandbox()
#  @brief   copy over jobs from production jenkins.
#  @return  <none>
jenkins_copy_jobs() {
    local excludes="--exclude=builds \
                    --exclude=archive \
                    --exclude=outOfOrderBuilds \
                    --exclude=lastStable \
                    --exclude=lastSuccessful \
                    --exclude=nextBuildNumber \
                    --exclude=log \
                    --exclude=*Mevo \
                    --exclude=*MEVO \
                    --exclude=*.log \
                    --exclude=*.txt \
                    --exclude=*.tmp \
                    --exclude=disk-usage.xml \
                    --exclude=build.xml \
                    --exclude=changelog.xml \
                    --exclude=revisionstate.xml \
                    --exclude=htmlreports \
                    --exclude=workspace*"

    for JOB_PREFIX in ${TRUNK_JOBS} ${DEFAULT_JOBS}; do
        echo "    rsync ${JOB_PREFIX}* jobs"
        rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB_PREFIX}* ${JENKINS_HOME}/jobs/
    done

    if [[ ${USER} == lfscidev ]]; then
        for JOB in ${OTHER_ADMIN_JOBS}; do
            echo "    rsync job ${JOB}"
            rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB} ${JENKINS_HOME}/jobs/
        done
    fi

    if [[ ${USER} == ca_urecci ]]; then
        for JOB in FB1405_RLD_ FB1405_RLD9_; do
            echo "    rsync job *${JOB}*"
            rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/*${JOB}* ${JENKINS_HOME}/jobs/
        done
    fi

    if [[ ${UBOOT} == true ]]; then
        JOB_PREFIX=UBOOT
        echo "    rsync ${JOB_PREFIX}* jobs"
        rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB_PREFIX}* ${JENKINS_HOME}/jobs/
    fi

    if [[ ${TEST_JOBS} == true ]]; then
        JOB_PREFIX=Test-
        echo "    rsync ${JOB_PREFIX}* jobs"
        rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB_PREFIX}* ${JENKINS_HOME}/jobs/
    fi

    if [[ ${DEV_VIEWS} == true ]]; then
        for JOB_PREFIX in LFS_KNIFE_-_ LFS_DEV_-_developer_-_; do
            echo "    rsync ${JOB_PREFIX}* jobs"
            rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB_PREFIX}* ${JENKINS_HOME}/jobs/
        done
    fi

    if [[ ${ADMIN_JOBS} == true ]]; then
        JOB_PREFIX=Admin_-_
        echo "    rsync ${JOB_PREFIX}* jobs"
        rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB_PREFIX}* ${JENKINS_HOME}/jobs/
    fi

    for BRANCH_VIEW in $(echo ${BRANCH_VIEWS} | tr ',' ' '); do
        if [[ ${BRANCH_VIEW} != trunk ]]; then
            for JOB_PREFIX in LFS_CI_-_ LFS_Prod_-_ PKGPOOL_-_; do
                echo "    rsync ${JOB_PREFIX}* jobs"
                rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB_PREFIX}${BRANCH_VIEW}_-_* ${JENKINS_HOME}/jobs
            done
        fi
    done

    if [[ "${LRC}" == "true" ]]; then
        for JOB_PREFIX in LFS_CI_-_LRC_-_ LFS_Prod_-_LRC_-_ PKGPOOL_-_LRC_-_; do
            echo "    rsync ${JOB_PREFIX}* jobs"
            rsync -a ${excludes} ${LRC_PROD_JENKINS_SERVER}:${LRC_PROD_JENKINS_JOBS}/${JOB_PREFIX}* ${JENKINS_HOME}/jobs/
        done
    fi
}

## @fn      jenkins_configure_deploy_ci_scripting_job()
#  @brief   disable job Admin_-_deployCiScripting in new Sandbox Jenkins.
#  @return  <none>
jenkins_configure_deploy_ci_scripting_job() {
    JOB_NAME="Admin_-_deployCiScripting"
    [[ ! -f ${JENKINS_HOME}/jobs/${JOB_NAME}/config.xml ]] && return
    echo "    Configure job ${JOB_NAME}"

    sed -i -e "s,<disabled>false</disabled>,<disabled>true</disabled>," \
           -e "s,<name>\*/master</name>,<name>\*/development</name>," \
           -e "s,\${WORKSPACE}/bin/unitTest.sh,#\${WORKSPACE}/bin/unitTest.sh," \
           -e "s,cd /ps/lfs/ci,cd \${HOME}/lfs-ci," \
           -e "s,git pull git-master master,git pull origin development," \
           ${JENKINS_HOME}/jobs/${JOB_NAME}/config.xml
}

## @fn      jenkins_plugins()
#  @brief   copy over plugins from production jenkins.
#  @details If KEEP_JENKINS_PLUGINS == "true" and $1 == "copy", the plugins
#           are copied from $JENKINS_HOME to /tmp. If KEEP_JENKINS_PLUGINS == "false"
#           and $2 == "restore" the plugins are copied from /tmp to $JENKINS_HOME.
#           If KEEP_JENKINS_PLUGINS == "false" the plugins are copied from production
#           server. KEEP_JENKINS_PLUGINS == "true" can be used if coping from production
#           server would take a long time because of slow network connection. This implies
#           that Sandbox already exists on the local machine of course and you want to
#           set it up from scratch.
#  @param   the mode (copy|restore).
#  @return  <none>
jenkins_plugins() {
    local saveDir="/tmp/Jenkins_plugins.bak"
    local mode=$1
    [[ ! -d ${saveDir} ]] && mkdir -p ${saveDir}

    echo "Jenkins plugins"
    if [[ "${KEEP_JENKINS_PLUGINS}" == "false" && "${mode}" == "copy" ]]; then
        echo "    Rsync plugins from ${PROD_JENKINS_SERVER} to ${saveDir}"
        rsync -a ${PROD_JENKINS_SERVER}:${PROD_JENKINS_HOME}/plugins ${saveDir}/
    fi

    if [[ "${KEEP_JENKINS_PLUGINS}" == "true" && "${mode}" == "copy" ]]; then
        echo "    Backup local plugins to ${saveDir}"
        cp -a ${JENKINS_PLUGINS} ${saveDir}
    elif [[ "${mode}" == "restore" ]]; then
        echo "    Copy plugins from ${saveDir} to ${JENKINS_HOME}"
        cp -a ${saveDir}/plugins ${JENKINS_HOME}
        rm -rf ${saveDir}
    fi
}

jenkins_update_plugins() {
    echo "    Update Jenkins plugins"
    rsync -a ${PROD_JENKINS_SERVER}:${PROD_JENKINS_HOME}/plugins ${JENKINS_HOME}/
}

## @fn      jenkins_get_configs()
#  @brief   get configuration from production jenkins.
#  @details Gets the config.xml files for the requested views
#           from production server and put those files into
#           /tmp/${VIEW}_config.xml.
#  @return  <none>
jenkins_get_configs() {
    echo "Get Jenkins view configuration from ${PROD_JENKINS_SERVER}..."
    for VIEW in $(echo ${BRANCH_VIEWS} | tr ',' ' '); do
        if [[ "${VIEW}" == "trunk" ]]; then
            echo "    Get ${VIEW} view configuration"
            curl -k https://${PROD_JENKINS_SERVER}/view/${VIEW}/config.xml --noproxy localhost > ${TMP}/${VIEW}_view_config.xml 2> /dev/null
        else
            local parentView=$(echo ${VIEW} | cut -c 3-)
            [[ $(echo ${VIEW} | cut -c 1-2) == MD ]] && parentView=$(echo ${VIEW} | cut -c 4-)
            echo "    Get ${VIEW} view configuration"
            curl -k https://${PROD_JENKINS_SERVER}/view/${parentView}/view/${VIEW}/config.xml --noproxy localhost > ${TMP}/${VIEW}_view_config.xml 2> /dev/null
        fi
    done

    for VIEW in $(echo ${ROOT_VIEWS} | tr ',' ' '); do
        echo "    Get ${VIEW} view configuration"
        curl -k https://${PROD_JENKINS_SERVER}/view/${VIEW}/config.xml --noproxy localhost > ${TMP}/${VIEW}_view_config.xml 2> /dev/null
    done
    # ADMIN view is mandatory. If -a is not specified it needs to be created explicitly.
    VIEW=ADMIN
    echo ${ROOT_VIEWS} | grep -q ${VIEW} || {
        echo "    Get ${VIEW} view configuration";
        curl -k https://${PROD_JENKINS_SERVER}/view/${VIEW}/config.xml --noproxy localhost > ${TMP}/${VIEW}_view_config.xml 2> /dev/null;
    }

    for VIEW in $(echo ${NESTED_VIEWS} | tr ',' ' '); do
        local parentTab=$(echo ${VIEW} | cut -d'/' -f1)
        local childTab=$(echo ${VIEW} | cut -d'/' -f2)
        echo "    Get ${parentTab}/view/${childTab} view configuration"
        curl -k https://${PROD_JENKINS_SERVER}/view/${parentTab}/view/${childTab}/config.xml --noproxy localhost > ${TMP}/${parentTab}_${childTab}_view_config.xml 2> /dev/null
    done

    if [[ "${LRC}" == "true" ]]; then
        echo "    Get LRC view configuration"
        curl -k https://${LRC_PROD_JENKINS_SERVER}/view/LRC/config.xml --noproxy localhost > ${TMP}/LRC_view_config.xml 2> /dev/null
    fi
}

## @fn      jenkins_start_sandbox()
#  @brief   start new Sandbox Jenkins on local machine in the background
#           via nohup and redirect stdout and stderr to $LOG_FILE. Also
#           see the global -g parameter.
#  @return  <none>
jenkins_start_sandbox() {
    if [[ ! ${START_OPTION} ]]; then
        echo "Export vars and start Jenkins server..."
        export LFS_CI_ROOT=${LFS_CI_ROOT}
        export LFS_CI_CONFIG_FILE=${LFS_CI_CONFIG_FILE}
        export JENKINS_HOME=${JENKINS_HOME}
        nohup java ${JVM_OPTS} -jar ${JENKINS_WAR} ${JENKINS_OPTS} > ${LOG_FILE} 2>&1 &
        PID=$!
        echo ${PID} > ${PID_FILE}
        echo "    java process ID: $(cat ${PID_FILE})"
        echo "    waiting for Jenkins to be fully running"
        sleep 15
        RET=1
        while [[ ${RET} -ne 0 ]]; do
            curl -s http://localhost:${HTTP_PORT} --noproxy localhost > /dev/null 2>&1
            RET=$?
            sleep 3
        done
        echo "    waiting for master node to become ready"
        java -jar ${JENKINS_CLI_JAR} -s http://localhost:${HTTP_PORT} wait-node-online ""
    elif [[ ${START_OPTION} == "sysv" ]]; then
        echo "Start Jenkins via /etc/init.d/jenkins"
        /etc/init.d/jenknis start
    fi
}

## @fn      jenkins_configure_sandbox()
#  @brief   configure new Sandbox Jenkins.
#  @details Take the views config.xml files from /tmp (see jenkins_get_configs()) and
#           send them to local Sandbox jenkins via the Jenkis HTTP API by using curl.
#           Beforehand create the views (tabs) in Sandbox by invoking setup-sandbox.gry
#           via jenkins CLI.
#  @return  <none>
jenkins_configure_sandbox() {
    local rootViews=$ROOT_VIEWS
    local nestedViews=$NESTED_VIEWS
    [[ -z ${rootViews} ]] && rootViews="None"
    [[ -z ${nestedViews} ]] && nestedViews="None"
    echo "Invoke groovy script on new Sandbox"
    echo "    ${SANDBOX_SCRIPT_DIR}/setup-sandbox.gry create_views ${rootViews} ${nestedViews} ${BRANCH_VIEWS} ${LRC}"
    java -jar ${JENKINS_CLI_JAR} -s http://localhost:${HTTP_PORT}/ groovy \
        ${SANDBOX_SCRIPT_DIR}/setup-sandbox.gry create_views ${rootViews} ${nestedViews} ${BRANCH_VIEWS} ${LRC}

    if [[ ! -z ${BRANCH_VIEWS} ]]; then
        echo "Configure Jenkins top branch views (tabs) in new Sandbox"
        for VIEW in $(echo ${BRANCH_VIEWS} | tr ',' ' '); do
            echo "    Configure $VIEW view"
            curl http://localhost:${HTTP_PORT}/view/${VIEW}/config.xml --noproxy localhost --data-binary @${TMP}/${VIEW}_view_config.xml
        done
    fi

    if [[ ! -z ${ROOT_VIEWS} ]]; then
        echo "Configure Jenkins top level views (tabs) in new Sandbox"
        for VIEW in $(echo ${ROOT_VIEWS} | tr ',' ' '); do
            echo "    Configure $VIEW view"
            curl http://localhost:${HTTP_PORT}/view/${VIEW}/config.xml --noproxy localhost --data-binary @${TMP}/${VIEW}_view_config.xml
        done
    fi
    VIEW=ADMIN
    echo ${ROOT_VIEWS} | grep -q ${VIEW} || {
        echo "    Configure $VIEW view";
        curl http://localhost:${HTTP_PORT}/view/${VIEW}/config.xml --noproxy localhost --data-binary @${TMP}/${VIEW}_view_config.xml;
    }

    if [[ ! -z ${NESTED_VIEWS} ]]; then
        echo "Configure Jenkins nested views (nested tabs) in new Sandbox"
        for VIEW in $(echo ${NESTED_VIEWS} | tr ',' ' '); do
            local parentTab=$(echo ${VIEW} | cut -d'/' -f1)
            local childTab=$(echo ${VIEW} | cut -d'/' -f2)
            echo "    Configure ${parentTab}/view/${childTab} view"
            curl http://localhost:${HTTP_PORT}/view/${parentTab}/view/${childTab}/config.xml --noproxy localhost --data-binary @${TMP}/${parentTab}_${childTab}_view_config.xml
        done
    fi

    if [[ "${LRC}" == "true" ]]; then
        echo "    Configure LRC view"
        curl http://localhost:${HTTP_PORT}/view/LRC/config.xml --noproxy localhost --data-binary @${TMP}/LRC_view_config.xml
    fi
}

## @fn      jenkins_configure_primary_view()
#  @brief   set trunk view as the primary view in Sandbox.
#  @return  <none>
jenkins_configure_primary_view() {
    echo "Set primary view to trunk"
    sed -i -e "s,<primaryView>All</primaryView>,<primaryView>trunk</primaryView>," ${JENKINS_HOME}/config.xml
}

## @fn      jenkins_configure_master_executors()
#  @brief   set number of executors for master to 4 in Sandbox.
#  @return  <none>
jenkins_configure_master_executors() {
    local numExecutors=4
    echo "Set number of executors to ${numExecutors} for master"
    sed -i -e "s,<numExecutors>2</numExecutors>,<numExecutors>${numExecutors}</numExecutors>," ${JENKINS_HOME}/config.xml
}

## @fn      jenkins_configure_version()
#  @brief   set version number of Jenkins in Sandbox.
#  @return  <none>
jenkins_configure_version() {
    echo "Set version number of Jenkins to ${JENKINS_VERSION}"
    sed -i -e "s,<version>1.0</version>,<version>${JENKINS_VERSION}</version>," ${JENKINS_HOME}/config.xml
}

## @fn      jenkins_configure_node_properties()
#  @brief   set properties for jenkins master node in Sandbox.
#  @return  <none>
jenkins_configure_node_properties() {
    sed -i -e 's,<label></label>,<label>master ulm  singleThreads testDummyHost multiThreads</label>,' ${JENKINS_HOME}/config.xml
    sed -i -e "s,<nodeProperties/>,<nodeProperties>\n\
     <hudson.slaves.EnvironmentVariablesNodeProperty>\n\
       <envVars serialization=\"custom\">\n\
         <unserializable-parents/>\n\
         <tree-map>\n\
           <default>\n\
             <comparator class=\"hudson.util.CaseInsensitiveComparator\"/>\n\
           </default>\n\
           <int>2</int>\n\
           <string>LFS_CI_ROOT</string>\n\
           <string>${LFS_CI_ROOT}</string>\n\
           <string>LFS_CI_SHARE_MIRROR</string>\n\
           <string>/var/fpwork</string>\n\
         </tree-map>\n\
       </envVars>\n\
     </hudson.slaves.EnvironmentVariablesNodeProperty>\n\
    </nodeProperties>," ${JENKINS_HOME}/config.xml
}

## @fn      jenkins_disable_build_jobs()
#  @brief   disable all jobs ending matching .*_Build$ in Sandbox.
#  @return  <none>
jenkins_disable_build_jobs() {
    if [[ "${DISABLE_BUILD_JOBS}" == "true" ]]; then
        echo "Disable all .*_Build$ jobs"
        find ${JENKINS_HOME}/jobs -type f -wholename "*_Build/config.xml" \
            -exec sed -i -e 's,<disabled>false</disabled>,<disabled>true</disabled>,' {} \;
    fi
}

## @fn      jenkins_reload_config()
#  @brief   reload jenkins config from disk on Sandbox.
#  @return  <none>
jenkins_reload_config() {
    echo "Reload Jenkins configuration from disk"
    java -jar ${JENKINS_CLI_JAR} -s http://localhost:${HTTP_PORT} reload-configuration
    echo "    wait for Jenkins master node"
    java -jar ${JENKINS_CLI_JAR} -s http://localhost:${HTTP_PORT} wait-node-online ""
}

## @fn      post_actions()
#  @brief   print some info to stdout.
#  @return  <none>
post_actions() {
    echo "LFS CI Sandbox is setup and running on ${HOST}."
    echo "    - Open a browser and connect http://${HOST}:${HTTP_PORT}"
    echo "    - This jenkins is not secured."
    echo "    - If security is needed, activate \"Enable security\" via http://${HOST}:${HTTP_PORT}/configureSecurity."
    if [[ ! ${START_OPTION} ]]; then
        echo "    - Java process ID is $(cat ${PID_FILE})"
    fi
}

## @fn      jenkins_stuff()
#  @brief   invoke all jenkins_* functions.
#  @return  <none>
jenkins_stuff() {
    jenkins_plugins "copy"
    jenkins_prepare_sandbox
    jenkins_copy_jobs
    jenkins_configure_deploy_ci_scripting_job
    jenkins_get_configs
    jenkins_plugins "restore"
    jenkins_start_sandbox
    jenkins_configure_sandbox
    jenkins_configure_primary_view
    jenkins_configure_master_executors
    jenkins_configure_version
    jenkins_configure_node_properties
    jenkins_disable_build_jobs
    jenkins_reload_config
}

purge_sandbox() {
    local ans="N"
    read -p "Removing ${LOCAL_WORK_DIR}/${SANDBOX_USER}/${JENKINS_DIR}: " ans
    if [[ "${ans}" == "y" || "${ans}" == "Y" ]]; then
        rm -rf ${LOCAL_WORK_DIR}/${SANDBOX_USER}/${JENKINS_DIR}
    else
        echo "Nothing was deleted"
    fi

    ans="N"
    read -p "Removing ${LFS_CI_ROOT} (y|N): " ans
    if [[ "${ans}" == "y" || "${ans}" == "Y" ]]; then
        rm -rf ${LFS_CI_ROOT}
    else
        echo "Nothing was deleted"
    fi
}

get_args() {
    while getopts ":r:n:b:w:i:c:s:t:f:g:delpjohaxuk" OPT; do
        case ${OPT} in
            b)
                BRANCH_VIEWS=$OPTARG
            ;;
            n)
                NESTED_VIEWS=$OPTARG
            ;;
            r)
                ROOT_VIEWS=$OPTARG
            ;;
            w)
                LOCAL_WORK_DIR=$OPTARG
            ;;
            i)
                CI_USER=$OPTARG
            ;;
            c)
                LRC_CI_USER=$OPTARG
            ;;
            s)
                LFS_CI_ROOT=$OPTARG
            ;;
            t)
                HTTP_PORT=$OPTARG
            ;;
            f)
                LFS_CI_CONFIG_FILE=${OPTARG}
            ;;
            g)
                START_OPTION=${OPTARG}
            ;;
            d)
                PURGE_SANDBOX="true"
            ;;
            e)
                DISABLE_BUILD_JOBS="false"
            ;;
            l)
                LRC="true"
            ;;
            p)
                KEEP_JENKINS_PLUGINS="true"
            ;;
            j)
                UPDATE_JENKINS="true"
            ;;
            o)
                JUST_START="true"
            ;;
            a)
                ADMIN_JOBS="true"
            ;;
            u)
                UBOOT="true"
            ;;
            x)
                DEV_VIEWS="true"
            ;;
            k)
                TEST_JOBS="true"
            ;;
            h)
                usage
            ;;
            *)
                echo "Use -h option to get help."
                exit 1
            ;;
        esac
    done

    PROD_JENKINS_HOME="${WORK_DIR}/${CI_USER}/${JENKINS_DIR}/home"
    PROD_JENKINS_JOBS="${PROD_JENKINS_HOME}/jobs"

    LRC_PROD_JENKINS_SERVER="lfs-lrc-ci.int.net.nokia.com"
    LRC_PROD_JENKINS_HOME="${WORK_DIR}/${LRC_CI_USER}/${JENKINS_DIR}/home"
    LRC_PROD_JENKINS_JOBS="${LRC_PROD_JENKINS_HOME}/jobs"

    HTTP_ADDRESS="0.0.0.0"
    JENKINS_VERSION="1.532.3"
    JENKINS_HOME="${LOCAL_WORK_DIR}/${SANDBOX_USER}/${JENKINS_DIR}/home"
    JENKINS_PLUGINS="${JENKINS_HOME}/plugins"
    JVM_OPTS="-Djava.io.tmpdir=/var/tmp"
    JENKINS_OPTS="--httpListenAddress=${HTTP_ADDRESS} --httpPort=${HTTP_PORT}"
    JENKINS_WAR="${LFS_CI_ROOT}/lib/java/jenkins/jenkins-${JENKINS_VERSION}.war"
    JENKINS_CLI_JAR="${LFS_CI_ROOT}/lib/java/jenkins/jenkins-cli-${JENKINS_VERSION}.jar"
    PID_FILE="${JENKINS_HOME}/jenkins.pid"
    LOG_FILE="${JENKINS_HOME}/jenkins.log"
    GIT_URL="ssh://git@psulm.nsn-net.net/projects/lfs-ci.git"
    SANDBOX_SCRIPT_DIR="${LFS_CI_ROOT}/sandbox"
    HOST=$(hostname)
    TMP="/tmp"
}

main() {
    get_args $*
    pre_checks
    pre_actions
    adjust_args

    if [[ ${PURGE_SANDBOX} == true ]]; then
        purge_sandbox
        exit $?
    fi

    if [[ ${UPDATE_JENKINS} == true ]]; then
        jenkins_copy_jobs
        jenkins_update_plugins
        jenkins_configure_deploy_ci_scripting_job
        exit $?
    fi

    if [[ ${JUST_START} == true ]]; then
        jenkins_start_sandbox
        exit $?
    fi

    git_stuff
    cd ${HOME}
    jenkins_stuff
    post_actions
}

main $*

