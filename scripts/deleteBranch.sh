#!/bin/bash

SVN=${SVN_SERVER_1}
SVN_DIR="isource/svnroot/BTS_SC_LFS/os"
SVN_TOOLS="trunk/bldtools"

deleteInSvn() {
    svn --username eambrosc --password jesusih --trust-server-cert --non-interactive ls ${SVN}/${SVN_DIR}/${BRANCH} && {
        echo svn move ${SVN}/${SVN_DIR}/${BRANCH} ${SVN}/${SVN_DIR}/obsolete;
        echo "deleted branch $BRANCH in svn";
    }

#    svn ls ${SVN}/${SVN_DIR}/${SVN_TOOLS}/locations-${BRANCH} && {
#        echo svn move ${SVN}/${SVN_DIR}/${SVN_TOOLS}/locations-${BRANCH} ${SVN}/${SVN_DIR}/${SVN_TOOLS}/obsolete;
#        echo "deleted locations-${BRANCH} in svn";
#    }
#
#    svn ls ${SVN}/${SVN_DIR}/${SVN_TOOLS}/locations-${BRANCH}_FSMR4 && {
#        echo svn move ${SVN}/${SVN_DIR}/${SVN_TOOLS}/locations-${BRANCH}_FSMR4 ${SVN}/${SVN_DIR}/${SVN_TOOLS}/obsolete;
#        echo "deleted locations-${BRANCH}_FSMR4 in svn";
#    }
#
#    svn ls ${SVN}/${SVN_DIR}/${SVN_TOOLS}/locations-LRC_${BRANCH} && {
#        echo svn move ${SVN}/${SVN_DIR}/${SVN_TOOLS}/locations-LRC_${BRANCH} ${SVN}/${SVN_DIR}/${SVN_TOOLS}/obsolete;
#        echo "deleted locations-LRC_${BRANCH}_FSMR4 in svn";
#    }
}

deleteOnShare() {
    echo "TODO"
}

deleteInSvn
deleteOnShare

