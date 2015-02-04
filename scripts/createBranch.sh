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
info "# DEBUG:       $DEBUG"
info "# COMMENT:     $COMMENT"
info "###############################################################"

SVN_SERVER=$(getConfig lfsSourceRepos)
SVN_DIR="os"

cmd() {
    if [ $DEBUG == true ]; then
        info $*
    else
        $*
    fi
}

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
cmd svn copy -r${REVISION} -m "${message}" --parents ${SVN_SERVER}/${svnPath} \
    ${SVN_SERVER}/${SVN_DIR}/${NEW_BRANCH}/trunk

info "LOCATIONS stuff"
cmd svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${locations} \
    ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}
cmd svn co ${SVN_SERVER}/${SVN_DIR}/tunk/bldtools/locations-${NEW_BRANCH}
cmd cd locations-${NEW_BRANCH}
cmd sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
cmd svn commit -m "added new location ${NEW_BRANCH}."
cmd svn delete -m "removed bldtools, because they are used always from MAINTRUNK" ${SVN_SERVER}/${SVN_DIR}/${NEW_BRANCH}/trunk/bldtools

if [[ "${FSMR4}" == "true" ]]; then
    info "FSMR4 stuff"
    cmd svn ls ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${SRC_BRANCH}_FSMR4
    if [[ $? != 0 ]]; then
        cmd svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-FSM_R4_DEV \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    else
        cmd svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${SRC_BRANCH}_FSMR4 \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    fi
    cmd svn co ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    cmd cd locations-${NEW_BRANCH}_FSMR4
    cmd sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
    cmd svn commit -m "added new location ${NEW_BRANCH}_FSMR4."
fi

featureBuild=0
echo ${NEW_BRANCH} | grep -q -e "^MD[12]" || featureBuild=1

if [[ "${LRC}" == "true" ]] && [[ $featureBuild -eq 1 ]]; then
    info "LRC stuff"
    cmd svn ls ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${SRC_BRANCH}
    if [[ $? != 0 ]]; then
        cmd svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    else
        cmd svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${SRC_BRANCH} \
            ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    fi
    cmd svn co ${SVN_SERVER}/${SVN_DIR}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    cmd cd locations-LRC_${NEW_BRANCH}
    cmd sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
    cmd svn commit -m "added new location LRC_${NEW_BRANCH}."
fi

info "GIT stuff"
cmd GIT_REVISION=\$\(svn cat ${SVN_SERVER}/${svnPath}/main/src-project/src/gitrevision\)
cmd git checkout ssh://git@${GIT_SERVER_1}/build/build
cmd git branch $NEW_BRANCH $GIT_REVISION
cmd git push origin $NEW_BRANCH

PROJECT_DIR="src-project"
info "DUMMY commit on $PROJECT_DIR"
cmd svn co ${SVN_SERVER}/${SVN_DIR}/${NEW_BRANCH}/trunk/main/${PROJECT_DIR}
[[ $DEBUG == true ]] && mkdir $PROJECT_DIR
[[ -d ${PROJECT_DIR} ]] && {
    cmd cd ${PROJECT_DIR};
    echo >> Dependencies;
    cmd svn commit -m "dummy commit" Dependencies;
} || {
    warning "Directory $PROJECT_DIR does not exist";
}

