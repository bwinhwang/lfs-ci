#!/bin/bash

set -e

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/subversion.sh

info "###############################################################"
info "# Variables from Jenkins"
info "# ----------------------"
info "# SRC_BRANCH:     $SRC_BRANCH"
info "# NEW_BRANCH:     $NEW_BRANCH"
info "# REVISION:       $REVISION"
info "# FSMR4:          $FSMR4"
info "# SOURCE_RELEASE: $SOURCE_RELEASE"
info "# ECL_URLS:       $ECL_URLS"
info "# COMMENT:        $COMMENT"
info "###############################################################"


SVN_SERVER=$(getConfig lfsSourceRepos)
SVN_DIR="os"
SRC_PROJECT="src-project"

if [[ "${SRC_BRANCH}" == "trunk" ]]; then
    LOCATIONS="pronb-developer"
    SVN_PATH="${SVN_DIR}/trunk"
else
    locations="${SRC_BRANCH}"
    SVN_PATH="${SVN_DIR}/${SRC_BRANCH}/trunk"
fi


__checkParams() {
    [[ ! ${SRC_BRANCH} ]] && { echo "SRC_BRANCH is missing"; exit 1; }
    [[ ! ${NEW_BRANCH} ]] && { echo "NEW_BRANCH is missing"; exit 1; }
    [[ ! ${REVISION} ]] && { echo "REVISION is missing"; exit 1; }
    [[ ! ${SOURCE_RELEASE} ]] && { echo "SOURCE_RELEASE is missing"; exit 1; }
    [[ ! ${ECL_URLS} ]] && { echo "ECL_URLS is missing"; exit 1; }
    [[ ! ${COMMENT} ]] && { echo "COMMENT is missing"; exit 1; }

    return 0
}

## @fn      svnCopyBranch()
#  @brief   copy branch in SVN.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyBranch() {
    info "--------------------------------------------------------"
    info "SVN: create branch for"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    local message="initial creation of ${newBranch} branch based on ${srcBranch} rev. ${REVISION}. \
    DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_SERVER}/${SVN_PATH} ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk. \
    $COMMENT"

    svnCopy -r${REVISION} -m \"${message}\" --parents ${SVN_SERVER}/${SVN_PATH} \
        ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk
}

## @fn      svnCopyLocations()
#  @brief   copy locations for branch in SVN.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyLocations() {
    info "--------------------------------------------------------"
    info "SVN: create locations for branch"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    svnCopy -m \"copy locations branch ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${LOCATIONS} \
        ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}
    svnCheckout ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}
    cd locations-${newBranch}
    sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies
    svnCommit -m \"added new location ${newBranch}.\"
    svnCommand delete -m \"removed bldtools, because they are used always from MAINTRUNK\" ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk/bldtools
}

## @fn      svnCopyLocationsFSMR4()
#  @brief   copy locations for branch for FSMR4 in SVN.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyLocationsFSMR4() {
    info "--------------------------------------------------------"
    info "SVN: create locations for FSMR4"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    if [[ "${srcBranch}" == "trunk" ]]; then
        svnCopy -m \"copy locations branch ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-FSM_R4_DEV \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
    else
        svnCopy -m \"copy locations branch ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${srcBranch}_FSMR4 \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
    fi
    svnCheckout ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
    cd locations-${newBranch}_FSMR4
    sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies
    svnCommit -m \"added new location ${newBranch}_FSMR4.\"
}

## @fn      svnCopyBranchLRC()
#  @brief   copy branch in SVN for LRC.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyBranchLRC() {
    info "--------------------------------------------------------"
    info "SVN: create branch for LRC"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch="LRC_$2"
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    local message="initial creation of ${newBranch} branch based on ${srcBranch} rev. ${REVISION}. \
    DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_SERVER}/${SVN_PATH} ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk. \
    $COMMENT"

    svnCopy -r${REVISION} -m \"${message}\" --parents ${SVN_SERVER}/${SVN_PATH} \
        ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk
}

## @fn      svnCopyLocationsLRC()
#  @brief   copy locations for branch for LRC in SVN.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyLocationsLRC() {
    info "--------------------------------------------------------"
    info "SVN: create locations for LRC"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    if [[ $srcBranch == "trunk" ]]; then
        svnCopy -m \"copy locations branch ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${newBranch}
    else
        svnCopy -m \"copy locations branch ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${srcBranch} \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${newBranch}
    fi

    svnCheckout ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${newBranch}
    cd locations-LRC_${newBranch}
    sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies
    svnCommit -m \"added new location LRC_${newBranch}.\"
}

## @fn      createBranchInGit()
#  @brief   create new branch in GIT
#  @param   <newBranch> new branch name
#  @return  <none>
createBranchInGit() {
    info "--------------------------------------------------------"
    info "GIT: create branch"
    info "--------------------------------------------------------"

    local newBranch=$1
    mustHaveValue "${newBranch}" "new branch"
    # TODO: get GIT server from config
    local gitServer="psulm.nsn-net.net"

    gitRevision=$(svn cat ${SVN_SERVER}/${SVN_PATH}/main/${SRC_PROJECT}/src/gitrevision)
    info "GIT revision: ${gitRevision}"
    git checkout ssh://git@${gitServer}/build/build
    git branch $newBranch $gitRevision
    git push origin $newBranch
}

svnDummyCommit() {
    info "--------------------------------------------------------"
    info "SVN: dummy commit on $SRC_PROJECT"
    info "--------------------------------------------------------"

    local newBranch=$1
    mustHaveValue "${newBranch}" "new branch"

    svnCheckout ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk/main/${SRC_PROJECT}
    if [[ -d ${SRC_PROJECT} ]]; then
        cd ${SRC_PROJECT}
        echo >> src/README
        svnCommit -m \"dummy commit\" src/README
    else
        warning "Directory $SRC_PROJECT does not exist"
    fi
}

svnDummyCommitLRC() {
    info "--------------------------------------------------------"
    info "SVN: dummy commit on $SRC_PROJECT for LRC"
    info "--------------------------------------------------------"

    local newBranch="LRC_$1"
    mustHaveValue "${newBranch}" "new branch"

    svnCheckout ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk/lrc/${SRC_PROJECT}
    if [[ -d ${SRC_PROJECT} ]]; then
        cd ${SRC_PROJECT}
        echo >> src/README
        svnCommit -m \"dummy commit LRC\" src/README
    else
        warning "Directory $SRC_PROJECT does not exist"
    fi
}

svnEditLocationsTxtFile() {
    # TODO: Create locations.txt from DB
    info "--------------------------------------------------------"
    info "SVN: edit locations.txt file"
    info "--------------------------------------------------------"

    local newBranch=$1
    mustHaveValue "${newBranch}" "new branch"
    local bldTools="bldtools"
    local locationsTxt="locations.txt"
    local yyyy=$(getBranchPart ${newBranch} YYYY)
    local mm=$(getBranchPart ${newBranch} MM)

    info "Add ${newBranch} to trunk/${bldTools}/${locationsTxt}"
    mkdir ${bldTools}
    svnCheckout --depth empty ${SVN_SERVER}/${SVN_DIR}/trunk/${bldTools} ${bldTools}
    cd ${bldTools}
    svn update ${locationsTxt}
    echo >> ${locationsTxt}

    if [[ ! "${LRC}" ]]; then
        echo "${newBranch}                           Feature Build ${newBranch} (all FB_PS_LFS_REL_${yyyy}_${mm}_xx...)" >> ${locationsTxt}
    fi
    if [[ "${FSMR4}" == "true" ]] && [[ "$(echo ${newBranch} | cut -c1,2)" == "MD" ]]; then
        echo "${newBranch}_FSMR4                     Feature Build ${newBranch} FSM-r4 stuff only (bi-weekly branch)" >> ${locationsTxt}
    fi
    if [[ "${FSMR4}" == "true" ]] && [[ "$(echo ${newBranch} | cut -c1,2)" == "FB" ]]; then
        echo "${newBranch}_FSMR4                     Feature Build ${newBranch} FSM-r4 stuff only" >> ${locationsTxt}
    fi
    if [[ "${LRC}" == "true" ]]; then
        echo "LRC_${newBranch}                       LRC locations (special LRC for ${newBranch} only)" >> ${locationsTxt}
    fi
    svnCommit -m \"Added ${newBranch} to file ${locationsTxt}\" ${locationsTxt}
}

svnCopyDelivery() {
    info "--------------------------------------------------------"
    info "SVN: copy delivery repository"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    local yyyy=$(getBranchPart ${newBranch} YYYY)
    local mm=$(getBranchPart ${newBranch} MM)
    local svnAddress="https://svne1.access.nokiasiemensnetworks.com/isource/svnroot"
    mustHaveValue "${yyyy}" "yyyy"
    mustHaveValue "${mm}" "mm"

    if [[ "$srcBranch" == "trunk" ]]; then
        svn ls ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_MAINBRANCH || {
            svnCopy ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_MAINBRANCH \
            ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_${newBranch};
        }
    else
        svn ls ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_${newBranch} || {
            svnCopy ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_${srcBranch} \
            ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_${newBranch};
        }
    fi
}


svnCopyDeliveryLRC() {
    info "--------------------------------------------------------"
    info "SVN: copy delivery repository for LRC"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    local yyyy=$(getBranchPart ${newBranch} YYYY)
    local mm=$(getBranchPart ${newBranch} MM)
    local svnAddress="https://svne1.access.nokiasiemensnetworks.com/isource/svnroot"
    mustHaveValue "${yyyy}" "yyyy"
    mustHaveValue "${mm}" "mm"

    if [[ "$srcBranch" == "trunk" ]]; then
        svn ls ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC || {
            svnCopy ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC \
            ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC_${newBranch};
        }
    else
        svn ls ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC_${newBranch} || {
            svnCopy ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC_${srcBranch} \
            ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC_${newBranch};
        }
    fi
}


#######################################################################
# main
#######################################################################

main() {

    __checkParams

    if [[ ! ${LRC} ]]; then
        svnCopyBranch ${SRC_BRANCH} ${NEW_BRANCH}
        svnCopyLocations ${SRC_BRANCH} ${NEW_BRANCH}
        createBranchInGit ${NEW_BRANCH}
        svnDummyCommit ${NEW_BRANCH}
        svnCopyDelivery ${SRC_BRANCH} ${NEW_BRANCH}
        if [[ "${FSMR4}" == "true" ]]; then
            svnCopyLocationsFSMR4 ${SRC_BRANCH} ${NEW_BRANCH}
        fi
    elif [[ ${LRC} == "true" ]]; then
        svnCopyBranchLRC ${SRC_BRANCH} ${NEW_BRANCH}
        svnCopyLocationsLRC ${SRC_BRANCH} ${NEW_BRANCH}
        svnDummyCommitLRC ${NEW_BRANCH}
        svnCopyDeliveryLRC ${SRC_BRANCH} ${NEW_BRANCH}
    fi

    svnEditLocationsTxtFile ${NEW_BRANCH}
}

main

