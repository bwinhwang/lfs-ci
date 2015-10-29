#!/bin/bash
#
# Startup script for the Jenkins Continuous Integration server
#
# chkconfig: - 85 15
# description: Jenkins Continous Integration server
# processname: java
# pidfile: /var/run/jenkins.pid


source /etc/rc.d/init.d/functions
export DAEMON_COREFILE_LIMI=unlimited

case $(hostname -s) in
    ulegcpmaxi)
        export LFS_CI_ROOT=/ps/lfs/ci
        export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/lfs-ci.cfg
        user=psulm
    ;;
    ullteb02)
        export LFS_CI_ROOT=/home/ca_lrcci/lfs-ci
        export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/lfs-lrc-ci.cfg
        user=ca_lrcci
    ;;
    ulegcpeag15)
        export LFS_CI_ROOT=/home/lfscidev/lfs-ci
        export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/development.cfg
        user=lfscidev
    ;;
    ulegcpcisand)
        export LFS_CI_ROOT=/home/ca_urecci/lfs-ci
        export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/lfs-urec-ci.cfg
        user=ca_urecci
    ;;
esac

pidfile=/var/run/jenkins.pid
lockfile=/var/lock/subsys/jenkins
prog="LFS Jenkins"
exec=java
group=pronb

start() {
    echo -n "Starting $prog: "
    touch $pidfile
    chown $user $pidfile
    daemon -user $user -group $group -pidfile $pidfile $LFS_CI_ROOT/bin/startJenkins.sh
    RETVAL=$?

    echo

    [ $RETVAL -eq 0 ] && touch $lockfile
}

stop() {
    [ `id -u` -eq 0 ] || return 4
    echo -n $"Shutting down $prog: "
    killproc -p $pidfile java
    RETVAL=$?

    echo
    [ $RETVAL -eq 0 ] && rm -f $lockfile
    return $RETVAL
}

rh_status() {
    status -p $pidfile $exec
}


# Let's start the fun
case "$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  restart)
        stop ; start
        ;;
  status)
        rh_status
        ;;
  *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac

exit 0
