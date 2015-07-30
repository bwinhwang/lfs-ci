#!/bin/bash

#
# Create a copy of production Jenkins on local machine.
#

#TODO:
# - Copy LRC trunk
# - Copy database from backup

ITSME=$(basename $0)

WORK_DIR="/var/fpwork"
PROD_JENKINS_SERVER="lfs-ci.emea.nsn-net.net"
PROD_JENKINS_HOME="${WORK_DIR}/psulm/lfs-jenkins/home"
PROD_JENKINS_JOBS="${PROD_JENKINS_HOME}/jobs"

# Defaults
BRANCH_VIEWS="trunk"
ROOT_VIEWS="ADMIN,UBOOT"
NESTED_VIEWS="DEV/Developer_Build,DEV/Knife_alpha"
DISABLE_BUILD_JOBS=true
LRC=true

while getopts ":r:n:b:h:e" OPT; do
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
        e)
            DISABLE_BUILD_JOBS=false
        ;;
        l)
            LRC=false
        ;;
        h)
            help
            exit 0
        ;;
    esac
done

HTTP_ADDRESS="0.0.0.0"
HTTP_PORT="8090"
JENKNIS_VERSION="1.532.3"
JENKINS_HOME="${WORK_DIR}/${USER}/lfs-jenkins/home"
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

help() {
cat << EOF

    Script in order to setup a LFS CI sandbox on the local machine.
    Jenkins will be installed into directory ${WORK_DIR}/\$USER/jenkins.
    CI scripting will be cloned to \$USER/lfs-ci pointing to branch development.
    Job and view configuration are copied from Jenkins server ${PROD_JENKINS_SERVER}.
    All .*_Build$ Jobs are disabled sandbox. If you want them enabled use the -e flag.
    LRC trunk is copied per default. If this should not be done use the -l flag.
    After the script has been finished check the system settings of the new sandbox.

    Usage:   $ITSME <create_views> <-r ROOT_VIEW_1,ROOT_VIEW_2,...,ROOT_VIEW_n> <-n ROOT_VIEW_1_1/SUB_VIEW,ROOT_VIEW_2_2/SUB_VIEW,...,ROOT_VIEW_n_n/SUB_VIEW> <-b trunk,FB1506> <-e> <-l>
    Example: $ITSME <creabe_view> -r UBOOT -n DEV/Developer_Build -b trunk,FB1503 -l

    Default arguments are: -r ADMIN,UBOOT -n DEV/Developer_Build,DEV/Knife_alpha -b trunk


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

    if [[ ! -w ${WORK_DIR} ]]; then
        echo -e "\n\tERROR: Ensure that ${WORK_DIR} is writable for user ${USER}.\n"
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
        echo "    Clone git repo psulm.nsn-net.net/projects/lfs-ci.git into ${LFS_CI_ROOT}"
        git clone ssh://git@psulm.nsn-net.net/projects/lfs-ci.git
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
    if [[ -d ${JENKINS_HOME} ]]; then 
        echo "    Remove dir ${JENKINS_HOME}"
        rm -rf ${WORK_DIR}/${USER}
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
}

## @fn      jenkins_disable_doply_ci_scripting_job()
#  @brief   disable some jobs in new sandbox Jenkins.
#  @return  <none>
jenkins_disable_doply_ci_scripting_job() {
    [[ ! -f ${JENKINS_HOME}/jobs/Admin_-_deployCiScripting/config.xml ]] && return
    echo "    Disable job Admin_-_deployCiScripting"
    sed -i -e "s,<disabled>false</disabled>,<disabled>true</disabled>," ${JENKINS_HOME}/jobs/Admin_-_deployCiScripting/config.xml
}

## @fn      jenkins_copy_plugins()
#  @brief   copy over plugins from LFS production jenkins.
#  @return  <none>
jenkins_copy_plugins() {
    echo "    Copy plugins from ${PROD_JENKINS_SERVER}"
    rsync -a ${PROD_JENKINS_SERVER}:${PROD_JENKINS_HOME}/plugins ${JENKINS_HOME}
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
    #TODO: HC path to .gry Script
    java -jar ${JENKINS_CLI_JAR} -s http://localhost:${HTTP_PORT}/ groovy \
        /home/eambrosc/nsn/LFS/lfs-ci/sandbox/setup-sandbox.gry create_views ${ROOT_VIEWS} ${NESTED_VIEWS} ${BRANCH_VIEWS}

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
    echo "Set version number of Jenkins to ${version}"
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
           <string>${HOME}/lfs-ci</string>\n\
           <string>LFS_CI_SHARE_MIRROR</string>\n\
           <string>/var/fpwork</string>\n\
         </tree-map>\n\
       </envVars>\n\
     </hudson.slaves.EnvironmentVariablesNodeProperty>\n\
    </nodeProperties>," ${JENKINS_HOME}/config.xml
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


## @fn      jenkins_stuff()
#  @brief   invoke all jenkins_* functions.
#  @return  <none>
jenkins_stuff() {
    jenkins_prepare_sandbox
    jenkins_copy_jobs
    jenkins_disable_doply_ci_scripting_job
    jenkins_copy_plugins
    jenkins_get_configs
    jenkins_start_sandbox
    jenkins_configure_sandbox
    jenkins_configure_primary_view
    jenkins_configure_master_executors
    jenkins_configure_version
    jenkins_configure_node_properties
    jenkins_disable_build_jobs
    jenkins_reload_config
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

