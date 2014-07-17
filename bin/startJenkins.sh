#!/bin/bash

main() {
    local LFS_CI_ROOT=/ps/lfs/ci

    source ${LFS_CI_ROOT}/lib/logging.sh
    source ${LFS_CI_ROOT}/lib/common.sh
    source ${LFS_CI_ROOT}/lib/config.sh

    local java=$(getConfig java)
    local jenkins_war=$(getConfig jenkinsWarFile)
    local JENKINS_HOME=$(getConfig jenkinsRoot)/home
    local JENKINS_ROOT=$(getConfig jenkinsRoot)/root
    local jenkinsMasterSslCertificate=$(getConfig jenkinsMasterSslCertificate)
    local jenkinsMasterSslPrivateKey=$(getConfig jenkinsMasterSslPrivateKey)
    local jenkinsMasterServerHttpPort=$(getConfig jenkinsMasterServerHttpPort)
    local jenkinsMasterServerHttpsPort=$(getConfig jenkinsMasterServerHttpsPort)

    export JENKINS_HOME JENKINS_ROOT LFS_CI_ROOT
    export TZ=UTC+0

    unset CI_LOGGING_LOGFILENAME
    unset CI_LOGGING_DURATION_START_DATE
    unset LFS_CI_TEMPDIR

    set -x

    mkdir -p ${JENKINS_HOME} ${JENKINS_ROOT} ${JENKINS_ROOT}/log
    ulimit -u 40960

    group=$(id -n -g)

    if [[ ${group} != pronb ]] ; then
        echo "wrong group ${group} , please switch to pronb"
        exit 1
    fi

    if [[ ! -e ${jenkins_war} ]] ; then
        echo "jenkins war file ${jenkins_war} does not exist"
        exit 1
    fi

    cd ${JENKINS_HOME}
    exec ${java} -jar ${jenkins_war}                          \
            --httpsPort=${jenkinsMasterServerHttpsPort}       \
            --httpPort=${jenkinsMasterServerHttpPort}         \
            --ajp13Port=-1                                    \
            --httpsCertificate=${jenkinsMasterSslCertificate} \
            --httpsPrivateKey=${jenkinsMasterSslPrivateKey}   \
            > ${JENKINS_ROOT}/log/jenkins.log 2>&1 
    set +x

}

export LFS_CI_ROOT=/ps/lfs/ci/
main
