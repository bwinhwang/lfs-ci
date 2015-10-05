#!/bin/bash

## @fn      startJenkinsMasterServer()
#  @brief   start the jenkins master server
#  @param   <none>
#  @return  <none>
startJenkinsMasterServer() {
    source ${LFS_CI_ROOT}/lib/logging.sh
    source ${LFS_CI_ROOT}/lib/common.sh
    source ${LFS_CI_ROOT}/lib/config.sh

    local java=$(getConfig java)
    local jenkins_war=$(getConfig jenkinsWarFile)
    local JENKINS_HOME=$(getConfig jenkinsHome)
    local JENKINS_ROOT=$(getConfig jenkinsRoot)

    local jenkinsMasterServerHttpPort=$(getConfig jenkinsMasterServerHttpPort)

    export JENKINS_HOME JENKINS_ROOT LFS_CI_ROOT
    export TZ=UTC+0

    unset CI_LOGGING_LOGFILENAME
    unset CI_LOGGING_DURATION_START_DATE
    unset LFS_CI_TEMPDIR

    mkdir -p ${JENKINS_HOME} ${JENKINS_ROOT} ${JENKINS_ROOT}/log
    ulimit -u 40960

    group=$(id -n -g)

    if [[ ! -e ${jenkins_war} ]] ; then
        echo "jenkins war file ${jenkins_war} does not exist"
        exit 1
    fi

#            -XX:-UseGCOverheadLimit                           \
    cd ${JENKINS_HOME}
    exec ${java}                                              \
            -XX:PermSize=512M -XX:MaxPermSize=4096M -Xmn128M -Xms1024M -Xmx4096M \
            -jar ${jenkins_war}                               \
            --httpPort=${jenkinsMasterServerHttpPort}         \
            --ajp13Port=-1                                    \
            > ${JENKINS_ROOT}/log/jenkins.log 2>&1 
}
set -x
startJenkinsMasterServer
