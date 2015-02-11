#!/bin/bash

set -e

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/subversion.sh

info "###############################################################"
info "# Variables from Jenkins"
info "# ----------------------"
info "# SRC_BRANCH:  $SRC_BRANCH"
info "# NEW_BRANCH:  $NEW_BRANCH"
info "# REVISION:    $REVISION"
info "# FSMR4:       $FSMR4"
info "# RELEASE:     $RELEASE_NAME"
info "# ECL_FILE:    $ECL_FILES"
info "# COMMENT:     $COMMENT"
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

## @fn      svnCopyBranch()
#  @brief   copy branch in SVN.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyBranch() {
    info "BRANCH stuff"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    local message="initial creation of ${newBranch} branch based on ${srcBranch} rev. ${REVISION}. \
    DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_SERVER}/${SVN_PATH} ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk. \
    $COMMENT"

    echo svnCopy -r${REVISION} -m \"${message}\" --parents ${SVN_SERVER}/${SVN_PATH} \
        ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk
}

## @fn      svnCopyLocations()
#  @brief   copy locations for branch in SVN.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyLocations() {
    info "LOCATIONS stuff"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    echo svnCopy -m \"copy locations for ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${LOCATIONS} \
        ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}
    echo svnCheckout ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}
    echo cd locations-${newBranch}
    echo sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies
    echo svnCommit -m \"added new location ${newBranch}.\"
    echo svnCommand delete -m \"removed bldtools, because they are used always from MAINTRUNK\" ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk/bldtools
}

## @fn      svnCopyLocationsFSMR4()
#  @brief   copy locations for branch for FSMR4 in SVN.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyLocationsFSMR4() {
    info "FSMR4 stuff"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    if [[ $srcBranch == "trunk" ]]; then
        echo svnCopy -m \"copy locations for ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-FSM_R4_DEV \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
    else
        echo svnCopy -m \"copy locations for ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${srcBranch}_FSMR4 \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
    fi
    echo svnCheckout ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
    echo cd locations-${newBranch}_FSMR4
    echo sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies
    echo svnCommit -m \"added new location ${newBranch}_FSMR4.\"
}

## @fn      svnCopyBranchLRC()
#  @brief   copy branch in SVN for LRC.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyBranchLRC() {
    info "BRANCH LRC stuff"

    local srcBranch=$1
    local newBranch="LRC_$2"
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    local message="initial creation of ${newBranch} branch based on ${srcBranch} rev. ${REVISION}. \
    DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_SERVER}/${SVN_PATH} ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk. \
    $COMMENT"

    echo svnCopy -r${REVISION} -m \"${message}\" --parents ${SVN_SERVER}/${SVN_PATH} \
        ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk
}

## @fn      svnCopyLocationsLRC()
#  @brief   copy locations for branch for LRC in SVN.
#  @param   <srcBranch> source branch
#  @param   <newBranch> new name
#  @return  <none>
svnCopyLocationsLRC() {
    info "LRC stuff"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    if [[ $srcBranch == "trunk" ]]; then
        echo svnCopy -m \"copy locations for ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${newBranch}
    else
        echo svnCopy -m \"copy locations for ${newBranch}\" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${srcBranch} \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${newBranch}
    fi

    echo svnCheckout ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${newBranch}
    echo cd locations-LRC_${newBranch}
    echo sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies
    echo svnCommit -m \"added new location LRC_${newBranch}.\"
}

## @fn      createBranchInGit()
#  @brief   create new branch in GIT
#  @param   <newBranch> new branch name
#  @return  <none>
createBranchInGit() {
    info "GIT stuff"

    local newBranch=$1
    mustHaveValue "${newBranch}" "new branch"
    # TODO: get GIT server from config
    local gitServer="psulm.nsn-net.net"

    echo GIT_REVISION=\$\(svnCommand cat ${SVN_SERVER}/${SVN_PATH}/main/${SRC_PROJECT}/src/gitrevision\)
    echo git checkout ssh://git@${gitServer}/build/build
    echo git branch $newBranch $GIT_REVISION
    echo git push origin $newBranch
}

dummyCommit() {
    info "DUMMY commit on $SRC_PROJECT"

    local newBranch=$1
    mustHaveValue "${newBranch}" "new branch"

    echo svnCheckout ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk/main/${SRC_PROJECT}
    if [[ -d ${SRC_PROJECT} ]]; then
        echo cd ${SRC_PROJECT}
        echo echo >> src/README
        echo svnCommit -m \"dummy commit\" src/README
    else
        warning "Directory $SRC_PROJECT does not exist"
    fi
}

dummyCommitLRC() {
    info "DUMMY commit on $SRC_PROJECT for LRC"

    local newBranch="LRC_$1"
    mustHaveValue "${newBranch}" "new branch"

    echo svnCheckout ${SVN_SERVER}/${SVN_DIR}/${newBranch}/trunk/lrc/${SRC_PROJECT}
    if [[ -d ${SRC_PROJECT} ]]; then
        echo cd ${SRC_PROJECT}
        echo echo >> src/README
        echo svnCommit -m \"dummy commit for LRC\" src/README
    else
        warning "Directory $SRC_PROJECT does not exist"
    fi
}

editLocationsTxtFile() {
    # TODO: Create locations.txt from DB
    info "EDIT locations.txt file"

    local newBranch=$1
    mustHaveValue "${newBranch}" "new branch"
    local bldTools="bldtools"
    local locationsTxt="locations.txt"

    info "Add ${newBranch} to trunk/${bldTools}/${locationsTxt}"
    mkdir ${bldTools}
    svn checkout --depth empty ${SVN_SERVER}/${SVN_DIR}/trunk/${bldTools} ${bldTools}
    cd ${bldTools}
    svn update ${locationsTxt}
    echo >> ${locationsTxt}
    if [[ "${FSMR4}" == "true" ]] && [[ "$(echo ${newBranch} | cut -c1,2)" == "MD" ]]; then
        echo "${newBranch}_FSMR4                    Feature Build ${newBranch} FSM-r4 stuff only (bi-weekly branch)" >> ${locationsTxt}
    fi
    if [[ "${FSMR4}" == "true" ]] && [[ "$(echo ${newBranch} | cut -c1,2)" == "FB" ]]; then
        echo "${newBranch}                          Feature Build ${newBranch} stuff only (bi-weekly branch)" >> ${locationsTxt}
    fi
    if [[ "${LRC}" == "true" ]]; then
        echo "LRC_${newBranch}                      LRC locations (special LRC for ${newBranch} only)" >> ${locationsTxt}
    fi
    echo "${newBranch}                          Feature Build ${newBranch} (all FB_PS_LFS_REL_2014_12_xx...)" >> ${locationsTxt}
    echo svnCommit -m \"Added ${newBranch} to file ${locationsTxt}\" ${locationsTxt}
}


#######################################################################
# main
#######################################################################

main() {
    if [[ ! ${LRC} ]]; then
        svnCopyBranch ${SRC_BRANCH} ${NEW_BRANCH}
        svnCopyLocations ${SRC_BRANCH} ${NEW_BRANCH}
        createBranchInGit ${NEW_BRANCH}
        dummyCommit ${NEW_BRANCH}
        editLocationsTxtFile ${NEW_BRANCH}
        if [[ "${FSMR4}" == "true" ]]; then
            svnCopyLocationsFSMR4 ${SRC_BRANCH} ${NEW_BRANCH}
        fi
    elif [[ ${LRC} == "true" ]]; then
        svnCopyBranchLRC ${SRC_BRANCH} ${NEW_BRANCH}
        svnCopyLocationsLRC ${SRC_BRANCH} ${NEW_BRANCH}
        dummyCommitLRC ${NEW_BRANCH}
    fi
}

main

