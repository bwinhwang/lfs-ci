#!/bin/bash

set -e

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh

info "###############################################################"
info "# Variables from Jenkins"
info "# ----------------------"
info "# SRC_BRANCH:  $SRC_BRANCH"
info "# NEW_BRANCH:  $NEW_BRANCH"
info "# REVISION:    $REVISION"
info "# FSMR4:       $FSMR4"
info "# ENABLE_JOBS: $ENABLE_JOBS"
info "# LRC:         $LRC"
info "# COMMENT:     $COMMENT"
info "###############################################################"

SVN_SERVER=$(getConfig lfsSourceRepos)
SVN_DIR="os"
PROJECT_DIR="src-project"

if [[ "$SRC_BRANCH" == "trunk" ]]; then
    locations="pronb-developer"
    svnPath="${SVN_DIR}/trunk"
else
    locations="${SRC_BRANCH}"
    svnPath="${SVN_DIR}/${SRC_BRANCH}/trunk"
fi

# Branch
message="initial creation of ${NEW_BRANCH} branch based on ${SRC_BRANCH} rev. ${REVISION}. \
DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_SERVER}/${svnPath} ${SVN_SERVER}/${SVN_DIR}/${NEW_BRANCH}/trunk"

info "BRANCH stuff"
echo svn copy -r${REVISION} -m "${message}" --parents ${SVN_SERVER}/${svnPath} \
    ${SVN_SERVER}/${SVN_DIR}/${NEW_BRANCH}/trunk

info "LOCATIONS stuff"
echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${locations} \
    ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}
echo svn co ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}
echo cd locations-${NEW_BRANCH}
echo sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
echo svn commit -m "added new location ${NEW_BRANCH}."
echo svn delete -m "removed bldtools, because they are used always from MAINTRUNK" ${SVN_SERVER}/${SVN_DIR}/${NEW_BRANCH}/trunk/bldtools

if [[ "${FSMR4}" == "true" ]]; then
    info "FSMR4 stuff"
    if [[ $SRC_BRANCH == "trunk" ]]; then
        echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-FSM_R4_DEV \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    else
        echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${SRC_BRANCH}_FSMR4 \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    fi
    echo svn co ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    echo cd locations-${NEW_BRANCH}_FSMR4
    echo sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
    echo svn commit -m "added new location ${NEW_BRANCH}_FSMR4."
fi

featureBuild=0
echo ${NEW_BRANCH} | grep -q -e "^MD[12]" || featureBuild=1

if [[ "${LRC}" == "true" ]] && [[ $featureBuild -eq 1 ]]; then
    info "LRC stuff"
    if [[ $SRC_BRANCH == "trunk" ]]; then
        echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    else
        echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${SRC_BRANCH} \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    fi
    echo svn co ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    echo cd locations-LRC_${NEW_BRANCH}
    echo sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
    echo svn commit -m "added new location LRC_${NEW_BRANCH}."
fi

info "GIT stuff"
echo GIT_REVISION=\$\(svn cat ${SVN_SERVER}/${svnPath}/main/${PROJECT_DIR}/src/gitrevision\)
echo git checkout ssh://git@${GIT_SERVER_1}/build/build
echo git branch $NEW_BRANCH $GIT_REVISION
echo git push origin $NEW_BRANCH

info "DUMMY commit on $PROJECT_DIR"
echo svn co ${SVN_SERVER}/${SVN_DIR}/${NEW_BRANCH}/trunk/main/${PROJECT_DIR}
[[ -d ${PROJECT_DIR} ]] && {
    echo cd ${PROJECT_DIR};
    echo echo >> Dependencies;
    echo svn commit -m "dummy commit" Dependencies;
} || {
    warning "Directory $PROJECT_DIR does not exist";
}

BLD_TOOLS="bldtools"
LOC_TXT="locations.txt"
info "Add ${NEW_BRANCH} to trunk/${BLD_TOOLS}/${LOC_TXT}"
mkdir ${BLD_TOOLS}
svn co --depth empty ${SVN_SERVER}/${SVN_DIR}/trunk/${BLD_TOOLS} ${BLD_TOOLS}
cd ${BLD_TOOLS}
svn update ${LOC_TXT}
if [[ "${FSMR4}" == "true" ]] && [[ "$(echo ${NEW_BRANCH} | cut -c1,2)" == "MD" ]]; then
    echo "${NEW_BRANCH}_FSMR4                    Feature Build ${NEW_BRANCH} FSM-r4 stuff only (bi-weekly branch)" >> ${LOC_TXT}
fi
if [[ "${FSMR4}" == "true" ]] && [[ "$(echo ${NEW_BRANCH} | cut -c1,2)" == "FB" ]]; then
    echo "${NEW_BRANCH}                          Feature Build ${NEW_BRANCH} stuff only (bi-weekly branch)" >> ${LOC_TXT}
fi
if [[ "${LRC}" == "true" ]]; then
    echo "LRC_${NEW_BRANCH}                      LRC locations (special LRC for ${NEW_BRANCH} only)" >> ${LOC_TXT}
fi
echo "${NEW_BRANCH}                          Feature Build ${NEW_BRANCH} (all FB_PS_LFS_REL_2014_12_xx...)" >> ${LOC_TXT}
echo svn commit -m "Added ${NEW_BRANCH} to file ${LOC_TXT}" ${LOC_TXT}

