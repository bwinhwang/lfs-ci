#!/bin/bash

set -e

echo "###############################################################"
echo "# Variables from Jenkins"
echo "# ----------------------"
echo "# SRC_BRANCH:  $SRC_BRANCH"
echo "# NEW_BRANCH:  $NEW_BRANCH"
echo "# REVISION:    $REVISION"
echo "# FSMR4:       $FSMR4"
echo "# ENABLE_JOBS: $ENABLE_JOBS"
echo "# LRC:         $LRC"
echo "# COMMENT:     $COMMENT"
echo "###############################################################"

svnBasePath="isource/svnroot/BTS_SC_LFS/os"

if [[ "$SRC_BRANCH" == "trunk" ]]; then
    locations="pronb-developer"
    svnPath="${svnBasePath}/trunk"
else
    locations="${SRC_BRANCH}"
    svnPath="${svnBasePath}/${SRC_BRANCH}/trunk"
fi

# Branch
message="initial creation of ${NEW_BRANCH} branch based on ${SRC_BRANCH} rev. ${REVISION}. \
DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_SERVER_1}/${svnPath} ${SVN_SERVER_1}/${svnBasePath}/${NEW_BRANCH}/trunk"

echo -e "\nBRANCH"
echo svn copy -r${REVISION} -m "${message}" --parents ${SVN_SERVER_1}/${svnPath} \
    ${SVN_SERVER_1}/${svnBasePath}/${NEW_BRANCH}/trunk

echo -e "\nLOCATIONS"
echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-${locations} \
    ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-${NEW_BRANCH}
echo svn co ${SVN_SERVER_1}/${svnBasePath}/tunk/bldtools/locations-${NEW_BRANCH}
echo cd locations-${NEW_BRANCH}
echo sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
echo svn commit -m "added new location ${NEW_BRANCH}."
echo svn delete -m "removed bldtools, because they are used always from MAINTRUNK" ${SVN_SERVER_1}/${svnBasePath}/${NEW_BRANCH}/trunk/bldtools

if [[ "${FSMR4}" == "true" ]]; then
    echo -e "\nFSMR4"
    echo svn ls ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-${SRC_BRANCH}_FSMR4
    if [[ $? != 0 ]]; then
        echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-FSM_R4_DEV \
            ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    else
        echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-${SRC_BRANCH}_FSMR4 \
            ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    fi
    echo svn co ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-${NEW_BRANCH}_FSMR4
    echo cd locations-${NEW_BRANCH}_FSMR4
    echo sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
    echo svn commit -m "added new location ${NEW_BRANCH}_FSMR4."
fi

featureBuild=0
echo $NEW_BRANCH | grep -q -e "^MD[12]" || featureBuild=1

if [[ "${LRC}" == "true" ]] && [[ $featureBuild -eq 1 ]]; then
    echo -e "\nLRC"
    echo svn ls ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-LRC_${SRC_BRANCH}
    if [[ $? != 0 ]]; then
        echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-LRC \
            ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    else
        echo svn copy -m "copy locations for ${NEW_BRANCH}" ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-LRC_${SRC_BRANCH} \
            ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    fi
    echo svn co ${SVN_SERVER_1}/${svnBasePath}/trunk/bldtools/locations-LRC_${NEW_BRANCH}
    echo cd locations-LRC_${NEW_BRANCH}
    echo sed -i -e "s/\/${SRC_BRANCH}\//\/${NEW_BRANCH}\/trunk\//" Dependencies
    echo svn commit -m "added new location LRC_${NEW_BRANCH}."
fi

echo -e "\nGIT"

echo GIT_REVISION=\$\(svn cat ${SVN_SERVER_1}/${svnPath}/main/src-project/src/gitrevision\)
echo git checkout ssh://git@${GIT_SERVER_1}/build/build
echo git branch $NEW_BRANCH $GIT_REVISION
echo git push origin $NEW_BRANCH
