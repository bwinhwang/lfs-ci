#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/subversion.sh

info "###############################################################"
info "# Variables from Jenkins"
info "# ----------------------"
info "# BRANCH:           $NEW_BRANCH"
info "# MOVE_SVN:         $MOVE_SVN"
info "# DELETE_JOBS:      $DELETE_JOBS"
info "# DELETE_SHARE:     $DELETE_SHARE"
info "# LRC_MOVE_SVN:     $LRC_MOVE_SVN"
info "# LRC_DELETE_JOBS:  $LRC_DELETE_JOBS"
info "# LRC_DELETE_SHARE: $DELETE_SHARE"
info "# COMMENT:          $COMMENT"
info "###############################################################"

SVN_REPO=$(getConfig lfsSourceRepos)
SVN_DIR="os"
SVN_BLD_DIR="trunk/bldtools"
SHARE="/build/home/CI_LFS/Release_Candidates"
BRANCH_TYPE=$(echo $BRANCH  | cut -c1,2)
YY=$(echo $BRANCH  | cut -c3,4)
MM=$(echo $BRANCH  | cut -c5,6)
YYYY=$((2000+YY))


## @fn      getEclValue()
#  @brief   get value from ecl for key
#  @param   {key} the key in the ECL file
#  @param   {branch} the branch
#  @return  <none>
getEclValue() {
    local key=$1
    local branch=$2
    local svnEclRepo=$(echo ${SVN_REPO} | awk -F/ '{print $1"//"$2$3}')
    #local value=$(svn cat ${SVN_CREDS} ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/${branch}/ECL_BASE/ECL | grep ${key} | cut -d'=' -f2)
    local value=$(svn cat --username eambrosc --password jesusih --non-interactive --trust-server-cert ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/${branch}/ECL_BASE/ECL | grep ${key} | cut -d'=' -f2)
    echo ${value}
}

## @fn      moveBranchSvn()
#  @brief   move $BRANCH in svn
#  @param   <none>
#  @return  <none>
moveBranchSvn() {
    svn ls ${SVN_CREDS} ${SVN_REPO}/${SVN_DIR}/${BRANCH} && {
        echo svn move -m "moved ${BRANCH} to obsolete" ${SVN_REPO}/${SVN_DIR}/${BRANCH} ${SVN_REPO}/${SVN_DIR}/obsolete;
    }

    svn ls ${SVN_CREDS} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} && {
        echo svn move -m "moved locations-${BRANCH} to obsolete" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }

    svn ls ${SVN_CREDS} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 && {
        echo svn move -m "moved locations-${BRANCH}_FSMR4 to obsolete" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }
    return 0
}

## @fn      LRC_moveBranchSvn()
#  @brief   move $BRANCH in svn for LRC
#  @param   <none>
#  @return  <none>
LRC_moveBranchSvn() {
    svn ls ${SVN_CREDS} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-LRC_${BRANCH} && {
        echo svn move -m "moved locations-LRC_${BRANCH} to obsolete" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-LRC_${BRANCH} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }
    return 0
}

## @fn      deleteBranchShare()
#  @brief   delete data for BRANCH on share
#  @param   <none>
#  @return  <none>
deleteBranchShare() {
    local keepRelease=$(getEclValue "ECL_PS_LFS_OS" ${BRANCH})
    local dirPattern="${BRANCH_TYPE}_PS_LFS_OS_${YYYY}_${MM}*"
    local dirsToDelete=$(find ${SHARE} -maxdepth 2 -type d -name "${dirPattern}" | grep -v ${keepRelease})

    info "keep release: ${keepRelease}"
    for DIR in $dirsToDelete
    do
        echo rm -rf $DIR
        info "Deleted $DIR"
    done
}

## @fn      LRC_deleteBranchShare()
#  @brief   delete date for BRANCH on share for LRC
#  @param   <none>
#  @return  <none>
LRC_deleteBranchShare() {
    local keepRelease=$(getEclValue "ECL_PS_LRC_LCP_LFS_OS" ${BRANCH})
    local dirPattern="${BRANCH_TYPE}_LRC_LCP_PS_LFS_OS_${YYYY}_${MM}*"
    local dirsToDelete=$(find ${SHARE} -maxdepth 2 -type d -name "${dirPattern}" | grep -v ${keepRelease})

    info "keep LRC release: ${keepRelease}"
    for DIR in $dirsToDelete
    do
        echo rm -rf $DIR
        info "Deleted $DIR"
    done
}

__checkParams() {
    [[ ! "$BRANCH" ]] && { error "BRANCH must be specified"; return 1; }
    echo $BRANCH | grep -e "^FB[0-9]\{4\}\|^MD[0-9]\{4\}" || { error "$BRANCH is not valid."; return 1; }
}

__checkParams || { error "Params check failed."; exit 1; }

[[ ${MOVE_SVN} == true ]] && moveBranchSvn || info "Not moving $BRANCH in SVN"
[[ ${DELETE_SHARE} == true ]] && deleteBranchShare || info "Not deleting $BRANCH on share"

[[ ${LRC_MOVE_SVN} == true ]] && LRC_moveBranchSvn || info "Not moving $BRANCH in SVN for LRC"
[[ ${LRC_DELETE_SHARE} == true ]] && LRC_deleteBranchShare || info "Not deleting $BRANCH on share for LRC"

