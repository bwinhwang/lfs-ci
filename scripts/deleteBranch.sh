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
info "# DEBUG:            $DEBUG"
info "# COMMENT:          $COMMENT"
info "###############################################################"

SVN_REPO=$(getConfig lfsSourceRepos)
SVN_DIR="os"
SVN_BLD_DIR="trunk/bldtools"
SHARE="/build/home/CI_LFS/Release_Candidates"
BLD_SHARE="/build/home/SC_LFS/releases/bld"
PKG_SHARE="/build/home/SC_LFS/pkgpool"


#######################################################################
#
# HELPER FUNCTIONS - maybe move them to common.sh
#
#######################################################################


## @fn      getEclValue()
#  @brief   get value from ecl for key
#  @param   {key} the key in the ECL file
#  @param   {branch} the branch
#  @return  <none>
getEclValue() {
    local key=$1
    local branch=$2
    local svnEclRepo=$(echo ${SVN_REPO} | awk -F/ '{print $1"//"$2$3}')
    local value=$(svn cat ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/${branch}/ECL_BASE/ECL | grep ${key} | cut -d'=' -f2)
    echo ${value}
}


#######################################################################
#
# HELPER FUNCTIONS
#
#######################################################################


__checkParams() {
    [[ ! "$BRANCH" ]] && { error "BRANCH must be specified"; return 1; }
    echo $BRANCH | grep -e "^FB[0-9]\{4\}\|^MD[0-9]\{4\}\|TEST_ERWIN" || { error "$BRANCH is not valid."; return 1; }
}

__cmd() {
    if [ $DEBUG == true ]; then
        debug $@
        echo [DEBUG] $@
    else
        info runnig command: $@
        echo runnig command: $@
        #eval $@
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
    svn ls ${SVN_REPO}/${SVN_DIR}/${BRANCH} && {
        __cmd svn move -m \"moved ${BRANCH} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${BRANCH} ${SVN_REPO}/${SVN_DIR}/obsolete;
    }

    svn ls ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} && {
        __cmd svn move -m \"moved locations-${BRANCH} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }

    svn ls ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 && {
        __cmd svn move -m \"moved locations-${BRANCH}_FSMR4 to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }
    return 0
}

## @fn      LRC_moveBranchSvn()
#  @brief   move $BRANCH in svn for LRC
#  @param   <none>
#  @return  <none>
LRC_moveBranchSvn() {
    svn ls ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-LRC_${BRANCH} && {
        __cmd svn move -m \"moved locations-LRC_${BRANCH} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-LRC_${BRANCH} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }
    return 0
}

## @fn      deleteBranchShare()
#  @brief   delete data for BRANCH on share
#  @param   <none>
#  @return  <none>
deleteBranchShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local keepRelease=$(getEclValue "ECL_PS_LFS_OS" ${BRANCH})
    local dirPattern="${branchType}_PS_LFS_OS_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${SHARE} -maxdepth 2 -type d -name "${dirPattern}" | grep -v ${keepRelease})

    info "CLEAN $SHARE"
    info "keep release: ${keepRelease}"
    for DIR in $dirsToDelete
    do
        __cmd rm -rf $DIR
    done
}

## @fn      deleteBranchBldShare()
#  @brief   delete data for BRANCH on bld share
#  @param   <none>
#  @return  <none>
deleteBranchBldShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local keepRelease=$(getEclValue "ECL_PS_LFS_OS" ${BRANCH})
    local dirPattern="${branchType}_PS_LFS_OS_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${BLD_SHARE} -maxdepth 2 -type d -name "${dirPattern}" | grep -v ${keepRelease})

    info "CLEAN $BLD_SHARE"
    info "keep release: ${keepRelease}"
    for DIR in $dirsToDelete
    do
        __cmd rm -rf $DIR
    done
}

## @fn      deleteBranchPkgShare()
#  @brief   delete data for BRANCH on pkgpool share
#  @param   <none>
#  @return  <none>
deleteBranchPkgShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local dirPattern="${branchType}_PS_LFS_PKG_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${PKG_SHARE} -maxdepth 1 -type d -name "${dirPattern}")

    info "CLEAN $PKG_SHARE"
    for DIR in $dirsToDelete
    do
        __cmd rm -rf $DIR
    done
}

## @fn      LRC_deleteBranchShare()
#  @brief   delete date for BRANCH on share for LRC
#  @param   <none>
#  @return  <none>
LRC_deleteBranchShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local keepRelease=$(getEclValue "ECL_PS_LRC_LCP_LFS_OS" ${BRANCH})
    local dirPattern="${branchType}_LRC_LCP_PS_LFS_OS_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${SHARE} -maxdepth 2 -type d -name "${dirPattern}" | grep -v ${keepRelease})

    info "CLEAN $SHARE LRC"
    info "keep LRC release: ${keepRelease}"
    for DIR in $dirsToDelete
    do
        __cmd rm -rf $DIR
    done
}

## @fn      LRC_deleteBranchBldShare()
#  @brief   delete date for BRANCH on bld share for LRC
#  @param   <none>
#  @return  <none>
LRC_deleteBranchBldShare() {
    local branchType=$(getBranchPart ${BRANCH} TYPE)
    local mm=$(getBranchPart ${BRANCH} MM)
    local yyyy=$(getBranchPart ${BRANCH} YYYY)
    local keepRelease=$(getEclValue "ECL_PS_LRC_LCP_LFS_OS" ${BRANCH})
    local dirPattern="${branchType}_LRC_LCP_PS_LFS_OS_${yyyy}_${mm}*"
    local dirsToDelete=$(find ${BLD_SHARE} -maxdepth 2 -type d -name "${dirPattern}" | grep -v ${keepRelease})

    info "CLEAN $BLD_SHARE LRC"
    info "keep LRC release: ${keepRelease}"
    for DIR in $dirsToDelete
    do
        __cmd rm -rf $DIR
    done
}

__checkParams || { error "Params check failed."; exit 1; }

[[ ${MOVE_SVN} == true ]] && moveBranchSvn || info "Not moving $BRANCH in repo"
[[ ${DELETE_SHARE} == true ]] && { deleteBranchShare; deleteBranchBldShare; deleteBranchPkgShare; } || info "Not deleting $BRANCH on share"

[[ ${LRC_MOVE_SVN} == true ]] && LRC_moveBranchSvn || info "Not moving $BRANCH in repo for LRC"
[[ ${LRC_DELETE_SHARE} == true ]] && { LRC_deleteBranchShare; LRC_deleteBranchBldShare; } || info "Not deleting $BRANCH on share for LRC"

