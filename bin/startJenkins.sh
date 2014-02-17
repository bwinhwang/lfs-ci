#!/bin/bash

ROOT=/var/fpwork/demx2fk3/ci
JENKINS_VERSION=1.532.2
JENKINS_WAR=${ROOT}/lib/java/jenkins/jenkins-${JENKINS_VERSION}.war
JENKINS_HOME=${ROOT}/home
JENKINS_ROOT=${ROOT}/root
JENKINS_ARGS=" --httpPort=1234
-httpListenAddress=
"

export JENKINS_HOME JENKINS_ROOT


mkdir -p ${JENKINS_HOME} ${JENKINS_ROOT} ${ROOT}/log
ulimit -u 40960

cd ${JENKINS_HOME}
/usr/bin/java -jar ${JENKINS_WAR} \
        --httpsPort=12443 \
        --httpsCertificate=${ROOT}/etc/lfs-ci.emea.nsn-net.net.crt \
        --httpsPrivateKey=${ROOT}/etc/lfs-ci.emea.nsn-net.net.key  \
        --httpPort=1280 \
        --ajp13Port=12800 \
        > ${ROOT}/log/jenkins.log 2>&1 







