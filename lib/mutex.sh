#!/bin/bash
## @file    mutex.sh
#  @brief   a mutex implementation
#  @details based on: http://wiki.bash-hackers.org/howto/mutex 

## @fn      mutex_exit()
#  @brief   mutex exit handler
#  @param   <none>
#  @return  <none>
mutex_exit() {
    info "Removing lock ${LOCKDIR}"
    rm -rf "${LOCKDIR}"
}

## @fn      mutex_lock()
#  @brief   lock a mutex
#  @param   {lockName}   name of the mutex lock
#  @return  <none>
mutex_lock() {

    local lockName=${1:-noName}

    # lock dirs/files
    LOCKDIR="/tmp/lfs-lock-${lockName}"
    PIDFILE="${LOCKDIR}/PID"

    # exit codes and text for them - additional features nobody needs :-)
    local ENO_SUCCESS=0; ETXT[0]="ENO_SUCCESS"
    local ENO_GENERAL=1; ETXT[1]="ENO_GENERAL"
    local ENO_LOCKFAIL=2; ETXT[2]="ENO_LOCKFAIL"
    local ENO_RECVSIG=3; ETXT[3]="ENO_RECVSIG"
    
    ###
    ### start locking attempt
    ###
    if mkdir "${LOCKDIR}" &>/dev/null; then
    
        # lock succeeded, install signal handlers before storing the PID just in case 
        # storing the PID fails
        echo "$$" >"${PIDFILE}" 
        # the following handler will exit the script on receiving these signals
        # the trap on "0" (EXIT) from above will be triggered by this trap's "exit" command!
        info "locking ${PIDFILE} success, installed signal handlers"
        exit_add mutex_exit
    
    else
    
        # lock failed, now check if the other PID is alive
        local OTHERPID="$(cat "${PIDFILE}")"
    
        # if cat wasn't able to read the file anymore, another instance probably is
        # about to remove the lock -- exit, we're *still* locked
        #  Thanks to Grzegorz Wierzowiecki for pointing this race condition out on
        #  http://wiki.grzegorz.wierzowiecki.pl/code:mutex-in-bash
        if [ $? != 0 ]; then
            warning "lock failed for ${LOCKDIR}, PID ${OTHERPID} is active" 
            return ${ENO_LOCKFAIL}
        fi
    
        if ! kill -0 $OTHERPID &>/dev/null; then
            # lock is stale, remove it and restart
            warning "removing stale lock of nonexistant PID ${OTHERPID}" 
            rm -rf "${LOCKDIR}"
            return ${ENO_LOCKFAIL}
        else
            # lock is valid and OTHERPID is active - exit, we're locked!
            warning "lock failed for ${LOCKDIR}, PID ${OTHERPID} is active" 
            return ${ENO_LOCKFAIL}
        fi
    
    fi
}

## @fn      mutex_unlock()
#  @brief   unlock a mutex
#  @param   <none>
#  @return  <none>
mutex_unlock() {
        rm -rf "${LOCKDIR}"
}
