#!/bin/bash

LFS_CI_ROOT=/ps/lfs/ci

source ${LFS_CI_ROOT}/lib/config.sh


JENKINS_WAR=${LFS_CI_ROOT}/lib/java/jenkins/jenkins-${jenkinsVersion}.war
JENKINS_HOME=${jenkinsRoot}/home
JENKINS_ROOT=${jenkinsRoot}/root

export JENKINS_HOME JENKINS_ROOT LFS_CI_ROOT

mkdir -p ${JENKINS_HOME} ${JENKINS_ROOT} ${JENKINS_ROOT}/log
ulimit -u 40960

group=$(id -n -g)

if [[ ${group} != pronb ]] ; then
    echo "wrong group ${group} , please switch to pronb"
    exit 1
fi


cd ${JENKINS_HOME}
exec ${java} -jar ${jenkinsWarFile}                                      \
        --httpsPort=12443                                             \
        --httpPort=1280                                               \
        --ajp13Port=-1                                                \
        --httpsCertificate=${jenkinsMasterSslCertificate} \
        --httpsPrivateKey=${jenkinsMasterSslPrivateKey} \
        > ${JENKINS_ROOT}/log/jenkins.log 2>&1 
