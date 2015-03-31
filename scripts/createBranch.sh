#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh

initTempDirectory
setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${NEW_BRANCH}"

info "###############################################################"
info "# Variables from Jenkins"
info "# ----------------------"
info "# SRC_BRANCH:           $SRC_BRANCH"
info "# NEW_BRANCH:           $NEW_BRANCH"
info "# REVISION:             $REVISION"
info "# FSMR4:                $FSMR4"
info "# FSMR4_ONLY:           $FSMR4_ONLY"
info "# SOURCE_RELEASE:       $SOURCE_RELEASE"
info "# ECL_URLS:             $ECL_URLS"
info "# COMMENT:              $COMMENT"
info "# DO_SVN:               $DO_SVN"
info "# DO_JENKINS:           $DO_JENKINS"
info "# DUMMY_COMMIT:         $DUMMY_COMMIT"
info "# COPY_DELIVERY:        $COPY_DELIVERY"
info "# UPDATE_LOCATIONS_TXT: $UPDATE_LOCATIONS_TXT"
info "# DO_DB_INSERT:         $DO_DB_INSERT"
info "# DO_GIT:               $DO_GIT"
info "# ACTIVATE_ROOT_JOBS:   $ACTIVATE_ROOT_JOBS"
info "###############################################################"

# TODO: Get it via getConfig()
SVN_REPO="https://svne1.access.nsn.com/isource/svnroot/BTS_SC_LFS"
SVN_DIR="os"
SRC_PROJECT="src-project"
VARS_FILE="VARIABLES.TXT"

if [[ "${SRC_BRANCH}" == "trunk" ]]; then
    LOCATIONS="pronb-developer"
    LOCATIONS_FSMR4="locations-FSM_R4_DEV"
    LOCATIONS_LRC="locations-LRC"
    SVN_PATH="${SVN_DIR}/trunk"
else
    LOCATIONS="${SRC_BRANCH}"
    LOCATIONS_FSMR4="locations-${srcBranch}_FSMR4"
    LOCATIONS_LRC="locations-LRC_${srcBranch}"
    SVN_PATH="${SVN_DIR}/${SRC_BRANCH}/trunk"
fi


__checkParams() {
    [[ ! ${SRC_BRANCH} ]] && { echo "SRC_BRANCH is missing"; exit 1; }
    [[ ! ${NEW_BRANCH} ]] && { echo "NEW_BRANCH is missing"; exit 1; }
    [[ ! ${REVISION} ]] && { echo "REVISION is missing"; exit 1; }
    [[ ! ${SOURCE_RELEASE} ]] && { echo "SOURCE_RELEASE is missing"; exit 1; }
    [[ ! ${ECL_URLS} ]] && { echo "ECL_URLS is missing"; exit 1; }
    [[ ! ${COMMENT} ]] && { echo "COMMENT is missing"; exit 1; }
    [[ ${FSMR4} == false ]] && [[ ${FSMR4_ONLY} == true ]] && { echo "FSMR4 can not be false in case FSMR4_ONLY is true"; exit 1; }

    return 0
}

## @fn     __preparation()
#  @brief  Create key=value pairs file which is sourced by Jenkins.
__preparation(){
    JENKINS_API_TOKEN=$(getConfig jenkinsApiToken)
    JENKINS_API_USER=$(getConfig jenkinsApiUser)
    mustHaveValue ${JENKINS_API_TOKEN} "Jenkins API token is missing."
    mustHaveValue ${JENKINS_API_USER} "Jenkins API user is missing."
    echo JENKINS_API_TOKEN=${JENKINS_API_TOKEN} > ${VARS_FILE}
    echo JENKINS_API_USER=${JENKINS_API_USER} >> ${VARS_FILE}
}

## @fn      svnCopyBranch()
#  @brief   create the new branch in SVN by coping the source branch.
#  @param   <srcBranch> name of source branch
#  @param   <newBranch> name of new branch
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
    DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_REPO}/${SVN_PATH} ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk. \
    $COMMENT"

    svn ls ${SVN_REPO}/${SVN_DIR}/${newBranch} || {
        svn copy -r ${REVISION} -m "${message}" --parents ${SVN_REPO}/${SVN_PATH} \
            ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk;
    }
}

## @fn      svnCopyLocations()
#  @brief   copy locations for the branch in SVN.
#  @param   <srcBranch> name of source branch
#  @param   <newBranch> name of new branch
#  @return  <none>
svnCopyLocations() {
    info "--------------------------------------------------------"
    info "SVN: create locations"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    svn ls ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${LOCATIONS} \
        ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch} || {
            svn copy -m "copy locations branch ${newBranch}" ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${LOCATIONS} \
                ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch};
            svn checkout ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch};
            cd locations-${newBranch};
            sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies;
            svn commit -m "added new location ${newBranch}.";
            svn delete -m "removed bldtools, because they are always used from MAINTRUNK" ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk/bldtools;
    }
}

## @fn      svnCopyLocationsFSMR4()
#  @brief   copy locations for the branch for FSMR4 in SVN.
#  @param   <srcBranch> name of the source branch
#  @param   <newBranch> name of the new branch
#  @return  <none>
svnCopyLocationsFSMR4() {
    info "--------------------------------------------------------"
    info "SVN: create locations for FSMR4"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    svn ls ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4 || {
        svn copy -m "copy locations branch ${newBranch}" ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/${LOCATIONS_FSMR4} \
            ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
        svn checkout ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
        cd locations-${newBranch}_FSMR4
        sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies
        svn commit -m "added new location ${newBranch}_FSMR4."
    }
}

## @fn      svnCopyBranchLRC()
#  @brief   copy the branch in SVN for LRC by coping source branch to new branch.
#  @param   <srcBranch> name of the source branch
#  @param   <newBranch> name of the new branch
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
    DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_REPO}/${SVN_PATH} ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk. \
    $COMMENT"

    svn ls ${SVN_REPO}/${SVN_PATH} || {
        svn copy -r${REVISION} -m "${message}" --parents ${SVN_REPO}/${SVN_PATH} \
            ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk
    }
}

## @fn      svnCopyLocationsLRC()
#  @brief   copy locations for branch for LRC in SVN.
#  @param   <srcBranch> name of the source branch
#  @param   <newBranch> name of the new branch
#  @return  <none>
svnCopyLocationsLRC() {
    info "--------------------------------------------------------"
    info "SVN: create locations for LRC"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch="LRC_$2"
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    svn ls ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch} || {
        svn copy -m "copy locations branch ${newBranch}" ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/${LOCATIONS_LRC} \
            ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}
        svn checkout ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}
        cd locations-${newBranch}
        sed -i -e "s/\/${srcBranch}\//\/${newBranch}\/trunk\//" Dependencies
        svn commit -m "added new location ${newBranch}."
    }
    svn delete -m "removed bldtools, because they are always used from MAINTRUNK" ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk/bldtools;
}

## @fn      createBranchInGit()
#  @brief   create new branch in GIT
#  @param   <newBranch> new branch name
#  @return  <none>
createBranchInGit() {
    info "--------------------------------------------------------"
    info "GIT: create branch"
    info "--------------------------------------------------------"

    if [[ "${DO_GIT}" == "false" ]]; then
        info "Not creating branch in GIT"
        return 0
    fi

    # TODO: check if branch already exists in GIT
    local branchExists="no"

    if [[ "${branchExists}" == "no" ]]; then
        local newBranch=$1
        mustHaveValue "${newBranch}" "new branch"
        # TODO: get GIT via getConfig()
        local gitServer="psulm.nsn-net.net"

        # -> die SVN URL kann auch aus file.cfg geholt werden.
        #    fix for LRC pending.
        gitRevision=$(svn cat -r${REVISION} ${SVN_REPO}/${SVN_PATH}/main/${SRC_PROJECT}/src/gitrevision)
        info "GIT revision: ${gitRevision}"
        git clone ssh://git@${gitServer}/build/build
        cd build
        git branch $newBranch $gitRevision
        git push origin $newBranch
    else
        info "Branch already exists in GIT"
    fi
}

## @fn      svnDummyCommit
#  @brief   perform a dummy commit in SVN
#  @param   <newBranch> new branch name
#  @return  <none>
svnDummyCommit() {
    info "--------------------------------------------------------"
    info "SVN: dummy commit on $SRC_PROJECT"
    info "--------------------------------------------------------"

    if [[ "${DUMMY_COMMIT}" == "false" ]]; then
        info "Not performig dummy commit."
        return 0
    fi

    local newBranch=$1
    mustHaveValue "${newBranch}" "new branch"

    svn checkout ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk/main/${SRC_PROJECT}
    if [[ -d ${SRC_PROJECT} ]]; then
        cd ${SRC_PROJECT}
        echo >> src/README
        svn commit -m "dummy commit" src/README
    else
        warning "Directory $SRC_PROJECT does not exist"
    fi
}

## @fn      svnDummyCommitLRC
#  @brief   perform a dummy commit in SVN for LRC
#  @param   <newBranch> new branch name (without LRC_ prefix)
#  @return  <none>
svnDummyCommitLRC() {
    info "--------------------------------------------------------"
    info "SVN: dummy commit on $SRC_PROJECT for LRC"
    info "--------------------------------------------------------"

    if [[ "${DUMMY_COMMIT}" == "false" ]]; then
        info "Not performig dummy commit."
        return 0
    fi

    local newBranch="LRC_$1"
    mustHaveValue "${newBranch}" "new branch"

    svn checkout ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk/lrc/${SRC_PROJECT}
    if [[ -d ${SRC_PROJECT} ]]; then
        cd ${SRC_PROJECT}
        echo >> src/README
        svn commit -m "dummy commit LRC" src/README
    else
        warning "Directory $SRC_PROJECT does not exist"
    fi
}

## @fn      svnEditLocationsTxtFile()
#  @brief   adapt locations.txt file
#  @param   <newBranch> new branch name
#  @return  <none>
svnEditLocationsTxtFile() {
    # TODO: Create locations.txt from DB
    info "--------------------------------------------------------"
    info "SVN: edit locations.txt file"
    info "--------------------------------------------------------"

    if [[ "${UPDATE_LOCATIONS_TXT}" == "false" ]]; then
        info "Not updating locations.txt files in SVN."
        return 0
    fi

    local newBranch=$1
    mustHaveValue "${newBranch}" "new branch"
    local bldTools="bldtools"
    local locationsTxt="locations.txt"
    local yyyy=$(getBranchPart ${newBranch} YYYY)
    local mm=$(getBranchPart ${newBranch} MM)

    info "Add ${newBranch} to trunk/${bldTools}/${locationsTxt}"
    mkdir ${bldTools}
    svn checkout --depth empty ${SVN_REPO}/${SVN_DIR}/trunk/${bldTools} ${bldTools}
    cd ${bldTools}
    svn update ${locationsTxt}

    if [[ ! "${LRC}" ]] && [[ "$(echo ${newBranch} | cut -c1,2)" == "FB" ]]; then
        echo "${newBranch}                           Feature Build ${newBranch} (all FB_PS_LFS_REL_${yyyy}_${mm}_xx...)" >> ${locationsTxt}
    fi

    if [[ ! "${LRC}" ]] && [[ "$(echo ${newBranch} | cut -c1,2)" == "MD" ]]; then
        echo "${newBranch}                           Feature Build ${newBranch} (bi-weekly branch)" >> ${locationsTxt}
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

    svn commit -m "Added ${newBranch} to file ${locationsTxt}" ${locationsTxt}
}

## @fn      svnCopyDelivery()
#  @brief   copy delivery repository.
#  @param   <newBranch> new branch name
#  @param   <srcBranch> source branch name
#  @return  <none>
svnCopyDelivery() {
    info "--------------------------------------------------------"
    info "SVN: copy delivery repository"
    info "--------------------------------------------------------"

    if [[ "${COPY_DELIVERY}" == "false" ]]; then
        info "Not coping delivery"
        return 0
    fi

    local srcBranch=$1
    local newBranch=$2
    local yyyy=$(getBranchPart ${newBranch} YYYY)
    local mm=$(getBranchPart ${newBranch} MM)
    local svnAddress=$(echo ${SVN_REPO} | awk -F/ '{print $1"//"$2$3"/"$4"/"$5}')
    mustHaveValue "${yyyy}" "yyyy"
    mustHaveValue "${mm}" "mm"

    if [[ "$srcBranch" == "trunk" ]]; then
        svn ls ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_MAINBRANCH && {
            svn copy -m "copy delivery repo" ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_MAINBRANCH \
            ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_${newBranch};
        }
    else
        svn ls ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_${newBranch} && {
            svn copy -m "copy delivery repo" ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_${srcBranch} \
            ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_${newBranch};
        }
    fi
}

## @fn      svnCopyDeliveryLRC()
#  @brief   copy delivery repository for LRC.
#  @param   <newBranch> new branch name
#  @param   <srcBranch> source branch name
#  @return  <none>
svnCopyDeliveryLRC() {
    info "--------------------------------------------------------"
    info "SVN: copy delivery repository for LRC"
    info "--------------------------------------------------------"

    if [[ "${COPY_DELIVERY}" == "false" ]]; then
        info "Not coping delivery for LRC."
        return 0
    fi

    local srcBranch=$1
    local newBranch=$2
    local yyyy=$(getBranchPart ${newBranch} YYYY)
    local mm=$(getBranchPart ${newBranch} MM)
    local svnAddress=$(echo ${SVN_REPO} | awk -F/ '{print $1"//"$2$3"/"$4"/"$5}')
    mustHaveValue "${yyyy}" "yyyy"
    mustHaveValue "${mm}" "mm"

    if [[ "$srcBranch" == "trunk" ]]; then
        svn ls ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC && {
            svn copy -m "copy delivery repo" ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC \
            ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC_${newBranch};
        }
    else
        svn ls ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC_${newBranch} && {
            svn copy -m "copy delivery repo" ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC_${srcBranch} \
            ${svnAddress}/BTS_D_SC_LFS_${yyyy}_${mm}/os/branches/PS_LFS_OS_LRC_${newBranch};
        }
    fi
}

## @fn      dbInsert()
#  @brief   insert the new branch into the lfs database
#  @param   <branch> the name of the branch
#  @return  <none>
dbInsert() {
    info "--------------------------------------------------------"
    info "DB: insert branch into lfspt database"
    info "--------------------------------------------------------"

    if [[ "${DO_DB_INSERT}" == "false" ]]; then
        info "Not inserting branch ${branch} into table branches of lfspt database."
        return 0
    fi

    local branch=$1
    local branchType=$(getBranchPart ${branch} TYPE)
    local yyyy=$(getBranchPart ${branch} YYYY)
    local mm=$(getBranchPart ${branch} MM)
    local regex="${branchType}_PS_LFS_OS_${yyyy}_${mm}_([0-9][0-9][0-9][0-9])"

    if [[ ${LRC} == "true" ]]; then
        branch="LRC_${branch}"
        regex="${branchType}_LRC_LCP_PS_LFS_OS_${yyyy}_${mm}_([0-9][0-9][0-9][0-9])"
    fi

    local sqlString="insert into branches \
    (branch_name, location_name, ps_branch_name, based_on_revision, based_on_release, release_name_regex, date_created, comment) \
    VALUES ('$branch', '$branch', '${branch}', ${REVISION}, '${RELEASE}', '${regex}', now(), '$COMMENT')"

    local dbName=$(getConfig MYSQL_db_name)
    local dbUser=$(getConfig MYSQL_db_username)
    local dbPass=$(getConfig MYSQL_db_password)
    local dbHost=$(getConfig MYSQL_db_hostname)
    local dbPort=$(getConfig MYSQL_db_port)

    echo $sqlString | mysql -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName}
}


#######################################################################
# main
#######################################################################

main() {

    __checkParams
    __preparation

    if [[ "${DO_SVN}" == "true" ]]; then
        if [[ ! ${LRC} ]]; then
            svnCopyBranch ${SRC_BRANCH} ${NEW_BRANCH}
            svnCopyLocations ${SRC_BRANCH} ${NEW_BRANCH}
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
        dbInsert ${NEW_BRANCH}
        createBranchInGit ${NEW_BRANCH}
    else
        info "$(basename $0): Nothing to do."
    fi
}

main

