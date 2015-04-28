#!/bin/bash

# TODO: Add DEBUG like in deleteBranch.sh

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh

initTempDirectory
setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${NEW_BRANCH} DEBUG=${DEBUG}"

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
info "# DESCRIPTION:          $DESCRIPTION"
info "# COMMENT:              $COMMENT"
info "# DO_SVN:               $DO_SVN"
info "# DO_JENKINS:           $DO_JENKINS"
info "# DUMMY_COMMIT:         $DUMMY_COMMIT"
info "# DO_DB_INSERT:         $DO_DB_INSERT"
info "# DO_GIT:               $DO_GIT"
info "# ACTIVATE_ROOT_JOBS:   $ACTIVATE_ROOT_JOBS"
info "# DEBUG:                $DEBUG"
info "###############################################################"

# TODO: Get it via getConfig()
SVN_REPO="https://svne1.access.nsn.com/isource/svnroot/BTS_SC_LFS"
SVN_DIR="os"
SRC_PROJECT="src-project"
VARS_FILE="VARIABLES.TXT"

if [[ "${SRC_BRANCH}" == "trunk" ]]; then
    LOCATIONS="locations-pronb-developer"
    LOCATIONS_FSMR4="locations-FSM_R4_DEV"
    LOCATIONS_LRC="locations-LRC"
    SVN_PATH="${SVN_DIR}/trunk"
else
    LOCATIONS="locations-${SRC_BRANCH}"
    LOCATIONS_FSMR4="locations-${srcBranch}_FSMR4"
    LOCATIONS_LRC="locations-LRC_${srcBranch}"
    SVN_PATH="${SVN_DIR}/${SRC_BRANCH}/trunk"
fi


__checkParams() {
    [[ ! ${SRC_BRANCH} ]] && { error "SRC_BRANCH is missing"; exit 1; }
    [[ ! ${NEW_BRANCH} ]] && { error "NEW_BRANCH is missing"; exit 1; }
    [[ ! ${REVISION} ]] && { error "REVISION is missing"; exit 1; }
    [[ ! ${SOURCE_RELEASE} ]] && { error "SOURCE_RELEASE is missing"; exit 1; }
    [[ ! ${ECL_URLS} ]] && { error "ECL_URLS is missing"; exit 1; }
    [[ ! ${COMMENT} ]] && { error "COMMENT is missing"; exit 1; }
    [[ ${FSMR4} == false ]] && [[ ${FSMR4_ONLY} == true ]] && { error "FSMR4 can not be false in case FSMR4_ONLY is true"; exit 1; }

    if [[ ${LRC} == true ]]; then
        echo ${NEW_BRANCH} | grep -q -e "^LRC_" && { error "LRC: \"LRC_\" is automatically added as prefix to NEW_BRANCH"; exit 1; }
    fi

    echo ${SOURCE_RELEASE} | grep -q _OS_ && {
        SOURCE_RELEASE=$(echo "${SOURCE_RELEASE/_OS_/_REL_}");
    }
}

## @fn     __preparation()
#  @brief  Create key=value pairs file which is sourced by Jenkins.
__preparation(){
    JENKINS_API_TOKEN=$(getConfig jenkinsApiToken)
    JENKINS_API_USER=$(getConfig jenkinsApiUser)
    mustHaveValue ${JENKINS_API_TOKEN} "Jenkins API token is missing."
    mustHaveValue ${JENKINS_API_USER} "Jenkins API user is missing."
    echo JENKINS_API_TOKEN=${JENKINS_API_TOKEN} > ${WORKSPACE}/${VARS_FILE}
    echo JENKINS_API_USER=${JENKINS_API_USER} >> ${WORKSPACE}/${VARS_FILE}
}

## @fn     __get_sql_insert()
#  @brief  Create the insert statement for branches table
__get_sql_string() {
    local descrCol=""
    local descrVal=""
    if [[ ! -z ${DESCRIPTION} ]]; then
        descrCol=", branch_description"
        descrVal=", '$DESCRIPTION'"
    fi

    echo "insert into branches \
    (branch_name, location_name, ps_branch_name, based_on_revision, based_on_release, release_name_regex, date_created, comment${descrCol}) \
    VALUES ('$branch', '$branch', '${branch}', ${REVISION}, '${SOURCE_RELEASE}', '${regex}', now(), '$COMMENT'${descrVal})"
}

__cmd() {
    if [[ $DEBUG == true ]]; then
        debug $@
        echo [DEBUG] $@
    else
        info runnig command: $@
        eval $@
    fi
}

## @fn      svnCopyBranch()
#  @brief   create the new branch in SVN by coping the source branch.
#  @param   <srcBranch> name of source branch
#  @param   <newBranch> name of new branch
#  @return  <none>
svnCopyBranch() {
    info "--------------------------------------------------------"
    info "SVN: create branch"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    local message="initial creation of ${newBranch} branch based on ${srcBranch} rev. ${REVISION}. \
    DESCRIPTION: svn cp -r${REVISION} --parents ${SVN_REPO}/${SVN_PATH} ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk. \
    $COMMENT"

    # TODO: Job shall fail in case branch already exists.
    #       This requirement is in collision with master option DO_SVN.
    svn ls ${SVN_REPO}/${SVN_DIR}/${newBranch} || {
        __cmd svn copy -r ${REVISION} -m \"${message}\" --parents ${SVN_REPO}/${SVN_PATH} \
            ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk;
    }
}

## @fn      svnCopyBranchLRC()
#  @brief   invoke "svnCopyBranch srcBranch newBranch"
#  @param   <srcBranch> name of the source branch
#  @param   <newBranch> name of the new branch
#  @return  <none>
svnCopyBranchLRC() {
    svnCopyBranch $1 $2
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

    local locations=$1
    local srcBranch=$2
    local newBranch=$3
    mustHaveValue "${locations}" "locations"
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    svn ls ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch} || {
            __cmd svn copy -m \"copy locations branch ${newBranch}\" ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/${locations} \
                ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch};
            __cmd svn checkout ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch};
            __cmd cd locations-${newBranch};
            __cmd sed -i -e "'s/\/os\/${srcBranch}\//\/os\/${newBranch}\/trunk\//'" Dependencies;
            __cmd svn commit -m \"added new location ${newBranch}.\";
            __cmd svn delete -m \"removed bldtools, because they are always used from MAINTRUNK\" ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk/bldtools;
    }
}

## @fn      svnCopyLocationsLRC()
#  @brief   invoce "svnCopyLocations $1 $2 "LRC_$3""
#  @param   <location> name of the location
#  @param   <srcBranch> name of the source branch
#  @param   <newBranch> name of the new branch
#  @return  <none>
svnCopyLocationsLRC() {
    svnCopyLocations $1 $2 $3
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
        __cmd svn copy -m \"copy locations branch ${newBranch}\" ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/${LOCATIONS_FSMR4} \
            ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
        __cmd svn checkout ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4
        __cmd cd locations-${newBranch}_FSMR4
        __cmd sed -i -e "'s/\/${srcBranch}\//\/${newBranch}\/trunk\//'" Dependencies
        __cmd svn commit -m \"added new location ${newBranch}_FSMR4.\"
    }
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
        local gitServer=$(getConfig lfsGitServer)
        mustHaveValue "${newBranch}" "new branch"
        mustHaveValue "${gitServer}" "git server"

        if [[ ${LRC} == true ]]; then
            newBranch=LRC_${newBranch}
            gitRevision=$(svn cat -r${REVISION} ${SVN_REPO}/${SVN_PATH}/lrc/${SRC_PROJECT}/src/gitrevision)
        else
            gitRevision=$(svn cat -r${REVISION} ${SVN_REPO}/${SVN_PATH}/main/${SRC_PROJECT}/src/gitrevision)
        fi

        info "GIT revision: ${gitRevision}"
        __cmd git clone ssh://git@${gitServer}/build/build
        __cmd cd build
        __cmd git branch $newBranch $gitRevision
        __cmd git push origin $newBranch
    else
        # TODO: Fail in case branch already exists.
        #       Maybe collision with master option DO_SVN.
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
    local newBranch="LRC_$1"
    svnDummyCommit "${newBranch}"
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

    if [[ ${LRC} == true ]]; then
        branch="LRC_${branch}"
        regex="${branchType}_LRC_LCP_PS_LFS_OS_${yyyy}_${mm}_([0-9][0-9][0-9][0-9])"
    fi

    local dbName=$(getConfig MYSQL_db_name)
    local dbUser=$(getConfig MYSQL_db_username)
    local dbPass=$(getConfig MYSQL_db_password)
    local dbHost=$(getConfig MYSQL_db_hostname)
    local dbPort=$(getConfig MYSQL_db_port)

    if [[ $DEBUG == true ]]; then
        echo "[DEBUG] $(__get_sql_string)"
    else
        echo $(__get_sql_string) | mysql -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName}
    fi
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
            svnCopyLocations ${LOCATIONS} ${SRC_BRANCH} ${NEW_BRANCH}
            if [[ "${FSMR4}" == "true" ]]; then
                svnCopyLocationsFSMR4 ${SRC_BRANCH} ${NEW_BRANCH}
            fi
            svnDummyCommit ${NEW_BRANCH}
        elif [[ ${LRC} == "true" ]]; then
            svnCopyBranchLRC ${SRC_BRANCH} LRC_${NEW_BRANCH}
            svnCopyLocationsLRC ${LOCATIONS_LRC} ${SRC_BRANCH} LRC_${NEW_BRANCH}
            svnDummyCommitLRC ${NEW_BRANCH}
        fi
        dbInsert ${NEW_BRANCH}
        createBranchInGit ${NEW_BRANCH}
    else
        info "$(basename $0): Nothing to do."
    fi
}

main

