#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh

info "###############################################################"
info "# Variables from Jenkins"
info "# ----------------------"
info "# BRANCH:          $BRANCH"
info "# MOVE_SVN:        $MOVE_SVN"
info "# DELETE_JOBS:     $DELETE_JOBS"
info "# MOVE_SHARE:      $MOVE_SHARE"
info "# LRC_MOVE_SVN:    $LRC_MOVE_SVN"
info "# LRC_DELETE_JOBS: $LRC_DELETE_JOBS"
info "# LRC_MOVE_SHARE:  $LRC_MOVE_SHARE"
info "# DEBUG:           $DEBUG"
info "# COMMENT:         $COMMENT"
info "###############################################################"

initTempDirectory
setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${BRANCH}"

SVN_REPO=$(getConfig lfsSourceRepos)
SVN_DIR="os"
SVN_BLD_DIR="trunk/bldtools"
SHARE="/build/home/CI_LFS/Release_Candidates"
BLD_SHARE="/build/home/SC_LFS/releases/bld"
PKG_SHARE="/build/home/SC_LFS/pkgpool"
SVN_OPTS="--non-interactive --trust-server-cert"
ARCHIVE_BASE="/build/home/psulm/genericCleanup"


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
    echo $BRANCH | grep -e "^FB[0-9]\{4\}\|^MD[0-9]\{5\}\|^LRC_FB[0-9]\{4\}\|TEST_ERWIN\|TESTERWIN" || { error "$BRANCH is not valid."; return 1; }
}

__checkOthers() {
    [[ -d ${ARCHIVE_BASE} ]] || { error "archive dir ${ARCHIVE_BASE} does not exist."; return 1; }
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

## @fn      archiveBranchShare()
#  @brief   delete data for BRANCH on share
#  @param   <none>
#  @return  <none>
archiveBranchShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local dirPattern="${branchType}_PS_LFS_OS_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${SHARE} -maxdepth 2 -type d -name "${dirPattern}")

    info "archive $SHARE"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

## @fn      archiveBranchBldShare()
#  @brief   delete data for BRANCH on bld share
#  @param   <none>
#  @return  <none>
archiveBranchBldShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local dirPattern="${branchType}_PS_LFS_OS_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${BLD_SHARE} -maxdepth 2 -type d -name "${dirPattern}")

    info "archive $BLD_SHARE"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

## @fn      archiveBranchPkgShare()
#  @brief   delete data for BRANCH on pkgpool share
#  @param   <none>
#  @return  <none>
archiveBranchPkgShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local dirPattern="${branchType}_PS_LFS_PKG_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${PKG_SHARE} -maxdepth 1 -type d -name "${dirPattern}")

    info "archive $PKG_SHARE"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

## @fn      LRC_archiveBranchShare()
#  @brief   delete date for BRANCH on share for LRC
#  @param   <none>
#  @return  <none>
LRC_archiveBranchShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local dirPattern="${branchType}_LRC_LCP_PS_LFS_OS_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${SHARE} -maxdepth 2 -type d -name "${dirPattern}")

    info "archive $SHARE LRC"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

## @fn      LRC_archiveBranchBldShare()
#  @brief   delete date for BRANCH on bld share for LRC
#  @param   <none>
#  @return  <none>
LRC_archiveBranchBldShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local dirPattern="${branchType}_LRC_LCP_PS_LFS_OS_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${BLD_SHARE} -maxdepth 2 -type d -name "${dirPattern}")

    info "archive $BLD_SHARE LRC"
    for DIR in $dirsToDelete
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
    done
}

__checkParams || { error "Params check failed."; exit 1; }
__checkOthers || { error "Checking some stuff failed."; exit 1; }

[[ ${MOVE_SVN} == true ]] && moveBranchSvn || info "Not moving $BRANCH in repo"
[[ ${MOVE_SHARE} == true ]] && { archiveBranchShare; archiveBranchBldShare; } || info "Not archiving $BRANCH on share"

[[ ${LRC_MOVE_SVN} == true ]] && LRC_moveBranchSvn || info "Not moving $BRANCH in repo for LRC"
[[ ${LRC_MOVE_SHARE} == true ]] && { LRC_archiveBranchShare; LRC_archiveBranchBldShare; } || info "Not archiving $BRANCH on share for LRC"

