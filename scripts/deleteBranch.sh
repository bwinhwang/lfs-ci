#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh

SVN_SERVER=$(getConfig lfsSourceRepos)
SVN_DIR="os"
SVN_BLD_DIR="trunk/bldtools"

## @fn      deleteBranchInSvn()
#  @brief   delete $BRANCH in svn
#  @param   <none>
#  @return  <none>
deleteBranchInSvn() {
    svn ls ${SVN_CREDS} ${SVN_SERVER}/${SVN_DIR}/${BRANCH} && {
        echo svn move -m "moved ${BRANCH} to obsolete" ${SVN_SERVER}/${SVN_DIR}/${BRANCH} ${SVN_SERVER}/${SVN_DIR}/obsolete;
    }

    svn ls ${SVN_CREDS} ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} && {
        echo svn move -m "moved locations-${BRANCH} to obsolete" ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }

    svn ls ${SVN_CREDS} ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 && {
        echo svn move -m "moved locations-${BRANCH}_FSMR4 to obsolete" ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }

    svn ls ${SVN_CREDS} ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/locations-LRC_${BRANCH} && {
        echo svn move -m "moved locations-LRC_${BRANCH} to obsolete" ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/locations-LRC_${BRANCH} ${SVN_SERVER}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
    }
    return 0
}

## @fn      deleteBranchOnShare()
#  @brief   delete $BRANCH on share
#  @param   <none>
#  @return  <none>
deleteBranchOnShare() {
    info "TODO: function deleteOnShare"
}

deleteBranchInSvn
deleteBranchOnShare
