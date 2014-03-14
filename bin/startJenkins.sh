#!/bin/bash

JAVA=/usr/lib/jvm/jre-1.6.0-openjdk.x86_64/bin/java
ROOT=/var/fpwork/${USER}/lfs-jenkins
LFS_CI_ROOT=/ps/lfs/ci
JENKINS_VERSION=1.532.2

JENKINS_WAR=${LFS_CI_ROOT}/lib/java/jenkins/jenkins-${JENKINS_VERSION}.war
JENKINS_HOME=${ROOT}/home
JENKINS_ROOT=${ROOT}/root

export JENKINS_HOME JENKINS_ROOT LFS_CI_ROOT

mkdir -p ${JENKINS_HOME} ${JENKINS_ROOT} ${JENKINS_ROOT}/log
ulimit -u 40960

group=$(id -n -g)

if [[ ${group} != pronb ]] ; then
    echo "wrong group ${group} , please switch to pronb"
    exit 1
fi


cd ${JENKINS_HOME}
exec ${JAVA} -jar ${JENKINS_WAR}                                      \
        --httpsPort=12443                                             \
        --httpPort=1280                                               \
        --ajp13Port=-1                                                \
        --httpsCertificate=${LFS_CI_ROOT}/etc/lfs-ci.emea.nsn-net.net.crt \
        --httpsPrivateKey=${LFS_CI_ROOT}/etc/lfs-ci.emea.nsn-net.net.key  \
        > ${JENKINS_ROOT}/log/jenkins.log 2>&1 
