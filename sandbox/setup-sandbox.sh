#!/bin/bash

#
# Create a copy of production Jenkins on local machine.
#

#TODO:
# - Database

ITSME=$(basename $0)

# Defaults
BRANCH_VIEWS="trunk"
NESTED_VIEWS="DEV/Developer_Build,DEV/Knife_alpha"
ROOT_VIEWS="ADMIN,UBOOT"
DISABLE_BUILD_JOBS=true
LRC=true
KEEP_JENKINS_PLUGINS=false
WORK_DIR="/var/fpwork"
LOCAL_WORK_DIR=${WORK_DIR}
CI_USER="psulm"
LRC_CI_USER="ca_lrcci"
SANDBOX_USER=${USER}

while getopts ":r:n:b:d:i:c:h:elp" OPT; do
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
        d)
            LOCAL_WORK_DIR=$OPTARG
        ;;
        i)
            CI_USER=$OPTARG
        ;;
        c)
            LRC_CI_USER=$OPTARG
        ;;
        e)
            DISABLE_BUILD_JOBS=false
        ;;
        l)
            LRC=false
        ;;
        p)
            KEEP_JENKINS_PLUGINS=true
        ;;
        h)
            help
            exit 0
        ;;
    esac
done

PROD_JENKINS_SERVER="lfs-ci.emea.nsn-net.net"
PROD_JENKINS_HOME="${WORK_DIR}/${CI_USER}/lfs-jenkins/home"
PROD_JENKINS_JOBS="${PROD_JENKINS_HOME}/jobs"

LRC_PROD_JENKINS_SERVER="lfs-lrc-ci.int.net.nokia.com"
LRC_PROD_JENKINS_HOME="${WORK_DIR}/${LRC_CI_USER}/lfs-jenkins/home"
LRC_PROD_JENKINS_JOBS="${LRC_PROD_JENKINS_HOME}/jobs"

HTTP_ADDRESS="0.0.0.0"
HTTP_PORT="8090"
JENKNIS_VERSION="1.532.3"
JENKINS_HOME="${LOCAL_WORK_DIR}/${SANDBOX_USER}/lfs-jenkins/home"
JENKINS_PLUGINS="${JENKINS_HOME}/plugins"
JVM_OPTS="-Djava.io.tmpdir=/var/tmp"
JENKINS_OPTS="--httpListenAddress=${HTTP_ADDRESS} --httpPort=${HTTP_PORT}"
LFS_CI_ROOT="${HOME}/lfs-ci"
JENKINS_WAR="${LFS_CI_ROOT}/lib/java/jenkins/jenkins-${JENKNIS_VERSION}.war"
JENKINS_CLI_JAR="${LFS_CI_ROOT}/lib/java/jenkins/jenkins-cli-${JENKNIS_VERSION}.jar"
LFS_CI_CONFIG_FILE="${LFS_CI_ROOT}/etc/development.cfg"
PID_FILE="${JENKINS_HOME}/jenkins.pid"
LOG_FILE="${JENKINS_HOME}/jenkins.log"
HOST=$(hostname)
TMP="/tmp"
GIT_URL="ssh://git@psulm.nsn-net.net/projects/lfs-ci.git"

help() {
cat << EOF

    Script in order to setup a LFS CI sandbox on the local machine.

    Jenkins will be installed into directory ${LOCAL_WORK_DIR}/\$USER/lfs-jenkins/home in
    which \$LOCAL_WORK_DIR defaults to /var/fpwork. This can be overridden by -d LOCAL_WORK_DIR.
    Be aware, that \$USER is always appended to \$WORK_DIR.
    CI scripting will be cloned to \${LFS_CI_ROOT} pointing to branch development.
    Job and view configuration are copied from Jenkins server ${PROD_JENKINS_SERVER}
    or ${PROD_JENKINS_SERVER} respectively. Per default all .*_Build$ Jobs will be 
    disabled in the sandbox. If you want them enabled use the -e flag. LRC trunk is 
    copied per default except -p flag is present.

    After the script has been finished check the system settings of the new sandbox.

    Example: $ITSME -r UBOOT -n DEV/Developer_Build -b trunk,FB1503 -l -p
             --> Copy UBOOT, Developer_Build (within DEV view) and trunk. Skip creating LRC on sandbox (-l).
                 Disable all .*_Build$ jobs (-e is missing) and keep already existing Jenkins plugins (-p).

    Options and Flag:
        -b Comma separated list of BRANCHES to be copied from LFS CI (not LRC branches). Defaluts to ${BRANCH_VIEWS}.
        -n Comma separated list of nested view that should be created in sandbox. Defaluts to ${NESTED_VIEWS}.
        -r Comma separated list of root views (top level tabs) that should be created in sandbox. Defaults to ${ROOT_VIEWS}.
        -d Specify \$LOCAL_WORK_DIR directory for Jenkins installation. Defaults to ${LOCAL_WORK_DIR}.
        -i lfs ci user. Defaults to ${CI_USER}.
        -c lfs lrc ci user. Defaults to ${LRC_CI_USER}.
        -e (flag) Disable all .*_Build$ jobs in sandbox. Defaults to ${DISABLE_BUILD_JOBS}.
        -l (flag) Create LRC trunk within sandbox. Defaults to ${LRC}.
        -p (flag) Keep jenkins plugins from existing sandbox installation. Defaults to ${KEEP_JENKINS_PLUGINS}.
        -h get help

EOF
}

## @fn      pre_actions()
#  @brief   check needed requirements
#  @return  <none>
pre_actions() {
    if [[ $(ps aux | grep java | grep jenkins) ]]; then
        echo -e "\n\tERROR: Jenkins is sill running.\n"
        exit 1
    fi
    if [[ -d ${LOCAL_WORK_DIR} && ! -w ${LOCAL_WORK_DIR} ]]; then
        echo -e "\n\tERROR: Ensure that ${LOCAL_WORK_DIR} is writable for user ${SANDBOX_USER}.\n"
        exit 2
    fi
}

## @fn      git_stuff()
#  @brief   clone or pull lfs-ci git repository in $HOME/lfs-ci
#  @return  <none>
git_stuff() {
    echo "Git stuff..."
    if [[ -d ${LFS_CI_ROOT} ]]; then
        echo "    ${LFS_CI_ROOT} exists"
        cd ${LFS_CI_ROOT}
        echo "    Checkout branch development"
        git checkout development
        echo "    Pulling branch development"
        git pull origin development
    else
        echo "    Git repo does not exist in ${LFS_CI_ROOT}."
        cd ${HOME}
        echo "    Clone git repo ${GIT_URL} into ${LFS_CI_ROOT}"
        git clone ${GIT_URL}
        cd ${LFS_CI_ROOT}
        echo "    Checkout branch development"
        git checkout development
    fi
}

## @fn      jenkins_prepare_sandbox()
#  @brief   create jenkins home from scratch.
#  @return  <none>
jenkins_prepare_sandbox() {
    echo "Jenkins stuff..."
    if [[ -d ${LOCAL_WORK_DIR}/${SANDBOX_USER} ]]; then 
        echo "    Remove dir ${LOCAL_WORK_DIR}/${SANDBOX_USER}"
        rm -rf ${LOCAL_WORK_DIR}/${SANDBOX_USER}
    fi
    echo "    Create dir ${JENKINS_HOME}/jobs"
    mkdir -p ${JENKINS_HOME}/jobs
}

## @fn      jenkins_prepare_sandbox()
#  @brief   copy over some jobs from LFS production jenkins.
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

    echo "    Copy jobs from ${PROD_JENKINS_SERVER}"
    for JOB_PREFIX in LFS_CI_-_trunk_-_ LFS_Prod_-_trunk_-_ PKGPOOL_-_trunk_-_ UBOOT_ Test- LFS_KNIFE_-_ LFS_BRANCHING_-_ LFS_DEV_-_developer_-_ Admin_-_reserveTarget Admin_-_deployCiScripting; do
        rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB_PREFIX}* ${JENKINS_HOME}/jobs/
    done

    for BRANCH_VIEW in $(echo ${BRANCH_VIEWS} | tr ',' ' '); do
        if [[ ${BRANCH_VIEW} != trunk ]]; then
            echo "    Copy jobs for ${BRANCH_VIEW} from ${PROD_JENKINS_SERVER}"
            for JOB_PREFIX in LFS_CI_-_ LFS_Prod_-_ PKGPOOL_-_; do
                rsync -a ${excludes} ${PROD_JENKINS_SERVER}:${PROD_JENKINS_JOBS}/${JOB_PREFIX}${BRANCH_VIEW}_-_* ${JENKINS_HOME}/jobs
            done
        fi
    done

    if [[ ${LRC} == true ]]; then
        echo "    Copy jobs from ${LRC_PROD_JENKINS_SERVER}"
        for JOB_PREFIX in LFS_CI_-_LRC_-_ LFS_Prod_-_LRC_-_ PKGPOOL_-_LRC_-_; do
            rsync -a ${excludes} ${LRC_PROD_JENKINS_SERVER}:${LRC_PROD_JENKINS_JOBS}/${JOB_PREFIX}* ${JENKINS_HOME}/jobs/
        done
    fi
}

## @fn      jenkins_disable_deploy_ci_scripting_job()
#  @brief   disable some jobs in new sandbox Jenkins.
#  @return  <none>
jenkins_disable_deploy_ci_scripting_job() {
    [[ ! -f ${JENKINS_HOME}/jobs/Admin_-_deployCiScripting/config.xml ]] && return
    echo "    Disable job Admin_-_deployCiScripting"
    sed -i -e "s,<disabled>false</disabled>,<disabled>true</disabled>," ${JENKINS_HOME}/jobs/Admin_-_deployCiScripting/config.xml
}

## @fn      jenkins_copy_plugins()
#  @brief   copy over plugins from LFS production jenkins.
#  @param   the mode (copy|restore).
#  @return  <none>
jenkins_plugins() {
    local saveDir="Jenkins_plugins.bak"
    local mode=$1

    echo "Jenkins plugins"
    if [[ ${KEEP_JENKINS_PLUGINS} == false && ${mode} == copy ]]; then
        echo "    Copy plugins from ${PROD_JENKINS_SERVER}"
        rsync -a ${PROD_JENKINS_SERVER}:${PROD_JENKINS_HOME}/plugins /tmp/${saveDir}/
    fi

    if [[ ${KEEP_JENKINS_PLUGINS} == true && ${mode} == "copy" ]]; then
        echo "    Backup local plugins"
        cp -a ${JENKINS_PLUGINS} /tmp/${saveDir}
    elif [[ ${mode} == "restore" ]]; then
        echo "    Restore local plugins"
        cp -a /tmp/${saveDir} ${JENKINS_PLUGINS}
        rm -rf /tmp/${saveDir}
    fi
}

## @fn      jenkins_get_configs()
#  @brief   get configuration from LFS production jenkins.
#  @return  <none>
jenkins_get_configs() {
    echo "Get Jenkins view configuration from ${PROD_JENKINS_SERVER}..."
    for VIEW in $(echo ${BRANCH_VIEWS} | tr ',' ' '); do
        if [[ ${VIEW} == trunk ]]; then
            echo "    Get ${VIEW} view configuration"
            curl -k https://${PROD_JENKINS_SERVER}/view/${VIEW}/config.xml --noproxy localhost > ${TMP}/${VIEW}_view_config.xml 2> /dev/null
        else
            local parentView=$(echo ${VIEW} | cut -c 3-)
            [[ $(echo ${VIEW} | cut -c 1-2) == "MD" ]] && parentView=$(echo ${VIEW} | cut -c 4-)
            echo "    Get ${VIEW} view configuration"
            curl -k https://${PROD_JENKINS_SERVER}/view/${parentView}/view/${VIEW}/config.xml --noproxy localhost > ${TMP}/${VIEW}_view_config.xml 2> /dev/null
        fi
    done

    for VIEW in $(echo ${ROOT_VIEWS} | tr ',' ' '); do
        echo "    Get ${VIEW} view configuration"
        curl -k https://${PROD_JENKINS_SERVER}/view/${VIEW}/config.xml --noproxy localhost > ${TMP}/${VIEW}_view_config.xml 2> /dev/null
    done

    for VIEW in $(echo ${NESTED_VIEWS} | tr ',' ' '); do
        local parentTab=$(echo ${VIEW} | cut -d'/' -f1)
        local childTab=$(echo ${VIEW} | cut -d'/' -f2)
        echo "    Get ${parentTab}/view/${childTab} view configuration"
        curl -k https://${PROD_JENKINS_SERVER}/view/${parentTab}/view/${childTab}/config.xml --noproxy localhost > ${TMP}/${parentTab}_${childTab}_view_config.xml 2> /dev/null
    done

    if [[ ${LRC} == true ]]; then
        echo "    Get LRC view configuration"
        curl -k https://${LRC_PROD_JENKINS_SERVER}/view/LRC/config.xml --noproxy localhost > ${TMP}/LRC_view_config.xml 2> /dev/null
    fi
}

## @fn      jenkins_start_sandbox()
#  @brief   start new sandbox Jenkins in the background.
#  @return  <none>
jenkins_start_sandbox() {
    echo "Export vars and start Jenkins server..."
    export LFS_CI_ROOT=${LFS_CI_ROOT}
    export LFS_CI_CONFIG_FILE=${LFS_CI_CONFIG_FILE}
    export JENKINS_HOME=${JENKINS_HOME}
    nohup java ${JVM_OPTS} -jar ${JENKINS_WAR} ${JENKINS_OPTS} > ${LOG_FILE} 2>&1 &
    PID=$!
    echo ${PID} > ${PID_FILE}
    echo "    java process ID: $(cat ${PID_FILE})"
    echo "    waiting 30 sec for Jenkins"
    sleep 30
}

## @fn      jenkins_start_sandbox()
#  @brief   configure new sandbox Jenkins.
#  @return  <none>
jenkins_configure_sandbox() {
    echo "Invoke groovy script on new sandbox..."
    java -jar ${JENKINS_CLI_JAR} -s http://localhost:${HTTP_PORT}/ groovy \
        ${LFS_CI_ROOT}/sandbox/setup-sandbox.gry create_views ${ROOT_VIEWS} ${NESTED_VIEWS} ${BRANCH_VIEWS} ${LRC}

    echo "Configure Jenkins top branch views (tabs) in new sandbox"
    for VIEW in $(echo ${BRANCH_VIEWS} | tr ',' ' '); do
        echo "    Configure $VIEW view"
        curl http://localhost:${HTTP_PORT}/view/${VIEW}/config.xml --noproxy localhost --data-binary @${TMP}/${VIEW}_view_config.xml
    done

    echo "Configure Jenkins top level views (tabs) in new sandbox"
    for VIEW in $(echo ${ROOT_VIEWS} | tr ',' ' '); do
        echo "    Configure $VIEW view"
        curl http://localhost:${HTTP_PORT}/view/${VIEW}/config.xml --noproxy localhost --data-binary @${TMP}/${VIEW}_view_config.xml
    done

    echo "Configure Jenkins nested views (nested tabs) in new sandbox"
    for VIEW in $(echo ${NESTED_VIEWS} | tr ',' ' '); do
        local parentTab=$(echo ${VIEW} | cut -d'/' -f1)
        local childTab=$(echo ${VIEW} | cut -d'/' -f2)
        echo "    Configure ${parentTab}/view/${childTab} view"
        curl http://localhost:${HTTP_PORT}/view/${parentTab}/view/${childTab}/config.xml --noproxy localhost --data-binary @${TMP}/${parentTab}_${childTab}_view_config.xml
    done

    if [[ ${LRC} == true ]]; then
        echo "    Configure LRC view"
        curl http://localhost:${HTTP_PORT}/view/LRC/config.xml --noproxy localhost --data-binary @${TMP}/LRC_view_config.xml
    fi
}

## @fn      jenkins_configure_primary_view()
#  @brief   set trunk view as the primary view.
#  @return  <none>
jenkins_configure_primary_view() {
    echo "Set primary view to trunk"
    sed -i -e "s,<primaryView>All</primaryView>,<primaryView>trunk</primaryView>," ${JENKINS_HOME}/config.xml
}

## @fn      jenkins_configure_master_executors()
#  @brief   set number of executors for master.
#  @return  <none>
jenkins_configure_master_executors() {
    local numExecutors=4
    echo "Set number of executors to ${numExecutors} for master"
    sed -i -e "s,<numExecutors>2</numExecutors>,<numExecutors>${numExecutors}</numExecutors>," ${JENKINS_HOME}/config.xml
}

## @fn      jenkins_configure_version()
#  @brief   set version number of Jenkins
#  @return  <none>
jenkins_configure_version() {
    echo "Set version number of Jenkins to ${JENKNIS_VERSION}"
    sed -i -e "s,<version>1.0</version>,<version>${JENKNIS_VERSION}</version>," ${JENKINS_HOME}/config.xml
}

## @fn      jenkins_configure_node_properties()
#  @brief   set properties for jenkins master node
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
#  @brief   disable all jobs ending matching .*_Build$
#  @return  <none>
jenkins_disable_build_jobs() {
    if [[ ${DISABLE_BUILD_JOBS} == true ]]; then
        echo "Disable all .*_Build$ jobs"
        find ${JENKINS_HOME}/jobs -type f -wholename "*_Build/config.xml" \
            -exec sed -i -e 's,<disabled>false</disabled>,<disabled>true</disabled>,' {} \;
    fi
}

## @fn      jenkins_reload_config()
#  @brief   reload jenkins config from disk.
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
    echo "    - Java process ID is $(cat ${PID_FILE})"
}

## @fn      jenkins_stuff()
#  @brief   invoke all jenkins_* functions.
#  @return  <none>
jenkins_stuff() {
    jenkins_plugins "copy"
    jenkins_prepare_sandbox
    jenkins_copy_jobs
    jenkins_disable_deploy_ci_scripting_job
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

main() {
    if [[ $1 == --help || $1 == -h ]]; then
        help
        exit 0
    fi
    pre_actions
    git_stuff
    jenkins_stuff
    post_actions
}

main $*

