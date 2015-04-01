#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh

info "###############################################################"
info "# Variables from Jenkins"
info "# ----------------------"
info "# BRANCH:              $BRANCH"
info "# MOVE_SVN:            $MOVE_SVN"
info "# DELETE_JOBS:         $DELETE_JOBS"
info "# DELETE_TEST_RESULTS: $DELETE_TEST_RESULTS"
info "# MOVE_SHARE:          $MOVE_SHARE"
info "# LRC_MOVE_SVN:        $LRC_MOVE_SVN"
info "# LRC_DELETE_JOBS:     $LRC_DELETE_JOBS"
info "# LRC_MOVE_SHARE:      $LRC_MOVE_SHARE"
info "# DB_UPDATE:           $DB_UPDATE"
info "# DEBUG:               $DEBUG"
info "# COMMENT:             $COMMENT"
info "###############################################################"

initTempDirectory
setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${BRANCH} DEBUG=${DEBUG}"

SVN_REPO="https://svne1.access.nsn.com/isource/svnroot/BTS_SC_LFS"
SVN_DIR="os"
SVN_BLD_DIR="trunk/bldtools"
SHARE="/build/home/CI_LFS/Release_Candidates"
BLD_SHARE="/build/home/SC_LFS/releases/bld"
PKG_SHARE="/build/home/SC_LFS/pkgpool"
SVN_OPTS="--non-interactive --trust-server-cert"
ARCHIVE_BASE=$(getConfig ADMIN_archive_share)
TEST_SERVER="ulegcpmoritz"
DIR_PATTERN=""


#######################################################################
#
# HELPER FUNCTIONS - maybe move them to common.sh
#
#######################################################################


## @fn      getValueFromEclFile()
#  @brief   get value from ecl for key
#  @param   {key} the key in the ECL file
#  @param   {branch} the branch
#  @return  <none>
getValueFromEclFile() {
    local key=$1
    local branch=$2
    local svnEclRepo=$(echo ${SVN_REPO} | awk -F/ '{print $1"//"$2$3}')

    svn ls ${SVN_OPTS} ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/${branch}/ECL_BASE/ECL 2> /dev/null
    if [[ $? -eq 0 ]]; then
        local value=$(svn cat ${SVN_OPTS} ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/${branch}/ECL_BASE/ECL | grep ${key} | cut -d'=' -f2)
    else
        info using ECL from obsolete
        local value=$(svn cat ${SVN_OPTS} ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/obsolete/${branch}/ECL_BASE/ECL | grep ${key} | cut -d'=' -f2)
    fi

    echo ${value}
}


#######################################################################
#
# HELPER FUNCTIONS
#
#######################################################################


__checkParams() {
    [[ ! "$BRANCH" ]] && { error "BRANCH must be specified"; return 1; }
    echo $BRANCH | grep -q -e "^FB[0-9]\{4\}\|^MD[0-9]\{5\}\|^LRC_FB[0-9]\{4\}\|^TST_\|TEST_ERWIN\|TESTERWIN" || { error "$BRANCH is not valid."; return 1; }
}

__checkOthers() {
    [[ -d ${ARCHIVE_BASE} ]] || { error "archive dir ${ARCHIVE_BASE} does not exist."; return 1; }
    which mysql > /dev/null 2>&1 || { error "mysql not available."; return 1; }
}

__cmd() {
    if [ $DEBUG == true ]; then
        debug $@
        echo [DEBUG] $@
    else
        info runnig command: $@
        eval $@
    fi
}

__getSubBranch() {
    local branch=$1
    echo ${branch} | grep -q '_'
    if [[ $? -ne 0 ]]; then
        echo ""
    else
        local subBranch=$(echo ${branch} | cut -d'_' -f2)
        echo ${subBranch}
    fi
}

#######################################################################
#
# WORKING FUNCTIONS
#
#######################################################################


## @fn      moveBranchSvn()
#  @brief   move $BRANCH in svn
#  @param   <none>
#  @return  <none>
moveBranchSvn() {
    info "--------------------------------------------------------"
    info "SVN: move branch in SVN"
    info "--------------------------------------------------------"

    svn ls ${SVN_OPTS} ${SVN_REPO}/${SVN_DIR}/${BRANCH} 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved ${BRANCH} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${BRANCH} ${SVN_REPO}/${SVN_DIR}/obsolete;
    }

    svn ls ${SVN_OPTS} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved locations-${BRANCH} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }

    svn ls ${SVN_OPTS} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved locations-${BRANCH} FSMR4 to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }

    return 0
}

## @fn      LRC_moveBranchSvn()
#  @brief   move $BRANCH in svn for LRC
#  @param   <none>
#  @return  <none>
LRC_moveBranchSvn() {
    info "--------------------------------------------------------"
    info "SVN: move branch in SVN for LRC"
    info "--------------------------------------------------------"

    local branch="${BRANCH}"
    svn ${SVN_OPTS} ls ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${branch} 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved locations-${branch} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${branch} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }

    svn ls ${SVN_OPTS} ${SVN_REPO}/${SVN_DIR}/${branch} 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved ${branch} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${branch} ${SVN_REPO}/${SVN_DIR}/obsolete;
    }

    return 0
}

getDirPattern() {
    local branch=$1
    local dbName=$(getConfig MYSQL_db_name)
    local dbUser=$(getConfig MYSQL_db_username)
    local dbPass=$(getConfig MYSQL_db_password)
    local dbHost=$(getConfig MYSQL_db_hostname)
    local dbPort=$(getConfig MYSQL_db_port)
    local sqlString="SELECT release_name_regex FROM branches WHERE branch_name='${branch}'"
    local dirPattern=$(echo "${sqlString}" | mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName})

    if [ $? -ne 0 ] || [ ! ${dirPattern} ]; then
        error "mysql command failed: ${sqlString}"
        exit 1
    fi

    dirPattern=$(echo ${dirPattern} | cut -d'(' -f1)
    DIR_PATTERN="${dirPattern}*"

    if [ "$DIR_PATTERN" == "*" ]; then
        error "Invalid directory patter: $DIR_PATTERN"
        exit 1
    fi 
}

## @fn      archiveBranchShare()
#  @brief   archive data for BRANCH on share
#  @param   <none>
#  @return  <none>
archiveBranchShare() {
    info "--------------------------------------------------------"
    info "SHARE: archiveBranchShare()"
    info "--------------------------------------------------------"

    local dirPattern=$DIR_PATTERN
    local dirsToDelete=$(find ${SHARE} -maxdepth 2 -type d -name "${dirPattern}")

    info "archive ${SHARE}"
    info "directory pattern: ${dirPattern}"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

## @fn      archiveBranchBldShare()
#  @brief   archive data for BRANCH on bld share
#  @param   <none>
#  @return  <none>
archiveBranchBldShare() {
    info "--------------------------------------------------------"
    info "SHARE: archiveBranchBldShare()"
    info "--------------------------------------------------------"

    local dirPattern=$DIR_PATTERN
    local dirsToDelete=$(find ${BLD_SHARE} -maxdepth 2 -type d -name "${dirPattern}")

    info "archive ${BLD_SHARE}"
    info "directory pattern: ${dirPattern}"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

## @fn      archiveBranchPkgShare()
#  @brief   archive data for BRANCH on pkgpool share
#  @param   <none>
#  @return  <none>
archiveBranchPkgShare() {
    info "--------------------------------------------------------"
    info "SHARE: archiveBranchPkgShare()"
    info "--------------------------------------------------------"

    local dirPattern=$DIR_PATTERN
    local dirsToDelete=$(find ${PKG_SHARE} -maxdepth 1 -type d -name "${dirPattern}")

    info "archive ${PKG_SHARE}"
    info "directory pattern: ${dirPattern}"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

## @fn      LRC_archiveBranchShare()
#  @brief   archive date for BRANCH on share for LRC
#  @param   <none>
#  @return  <none>
LRC_archiveBranchShare() {
    info "--------------------------------------------------------"
    info "SHARE: LRC_archiveBranchShare()"
    info "--------------------------------------------------------"

    local dirPattern=$DIR_PATTERN
    local dirsToDelete=$(find ${SHARE} -maxdepth 2 -type d -name "${dirPattern}")

    info "archive ${SHARE} LRC"
    info "directory pattern: ${dirPattern}"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

## @fn      LRC_archiveBranchBldShare()
#  @brief   archive date for BRANCH on bld share for LRC
#  @param   <none>
#  @return  <none>
LRC_archiveBranchBldShare() {
    info "--------------------------------------------------------"
    info "SHARE: LRC_archiveBranchBldShare()"
    info "--------------------------------------------------------"

    local dirPattern=$DIR_PATTERN
    local dirsToDelete=$(find ${BLD_SHARE} -maxdepth 2 -type d -name "${dirPattern}")

    info "archive ${BLD_SHARE} LRC"
    info "directory pattern: ${dirPattern}"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

deleteTestResults() {
    info "--------------------------------------------------------"
    info "TESTS: deleteTestResults()"
    info "--------------------------------------------------------"

    local subString=$(__getSubBranch ${BRANCH})
    local dirPattern=$DIR_PATTERN
    if [[ "${subString}" != "" ]]; then
        info "sub branch: ${subString}"
        echo ${dirPattern} | grep -q ${subString} || { echo sub branch ${subString} is not in directory pattern ${dirPattern}; exit 1; }
    else
        yyyy=$(getBranchPart ${BRANCH} YYYY)
        mm=$(getBranchPart ${BRANCH} MM)
        branchType=$(getBranchPart ${BRANCH} TYPE)
        echo ${dirPattern} | grep -q ${branchType}_PS_LFS_OS_${yyyy}_${mm} || { echo ${branchType}_PS_LFS_OS_${yyyy}_${mm} is not in directory pattern ${dirPattern}; exit 1; }
    fi
    __cmd ssh ${TEST_SERVER} rm -rf /lvol2/production_jenkins/test-repos/src-fsmtest/${dirPattern}
}

## @fn      dbUpdate()
#  @brief   set branch to closed in DB
#  @param   <branch> the name of the branch
#  @return  <none>
dbUpdate() {
    info "--------------------------------------------------------"
    info "DB: update branch to closed in lfspt database"
    info "--------------------------------------------------------"

    local branch=${BRANCH}
    local sqlString="UPDATE branches SET status='closed' WHERE branche_name='${branch}'"

    local dbName=$(getConfig MYSQL_db_name)
    local dbUser=$(getConfig MYSQL_db_username)
    local dbPass=$(getConfig MYSQL_db_password)
    local dbHost=$(getConfig MYSQL_db_hostname)
    local dbPort=$(getConfig MYSQL_db_port)

    if [ $DEBUG == true ]; then
        debug $sqlString
        echo [DEBUG] $sqlString
    else
        info "updating DB: $sqlString"
        echo $sqlString | mysql -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName}
    fi
}


__checkParams || { error "Params check failed."; exit 1; }
__checkOthers || { error "Checking some stuff failed."; exit 1; }

getDirPattern ${BRANCH}

[[ ${MOVE_SVN} == true ]] && moveBranchSvn || info "Not moving $BRANCH in repo"
[[ ${MOVE_SHARE} == true ]] && { archiveBranchShare; archiveBranchBldShare; } || info "Not archiving $BRANCH on share"
[[ ${DELETE_TEST_RESULTS} == true ]] && deleteTestResults || info "Not deleting test results"
[[ ${DB_UPDATE} == true ]] && dbUpdate || info "Not updating DB."

[[ ${LRC_MOVE_SVN} == true ]] && LRC_moveBranchSvn || info "Not moving $BRANCH in repo for LRC"
[[ ${LRC_MOVE_SHARE} == true ]] && { LRC_archiveBranchShare; LRC_archiveBranchBldShare; } || info "Not archiving $BRANCH on share for LRC"

