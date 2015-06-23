#!/bin/bash

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
info "# SOURCE_RELEASE:       $SOURCE_RELEASE"
info "# ECL_URLS:             $ECL_URLS"
info "# DESCRIPTION:          $DESCRIPTION"
info "# COMMENT:              $COMMENT"
info "# FSMR4:                $FSMR4"
info "# DO_SVN:               $DO_SVN"
info "# DO_JENKINS:           $DO_JENKINS"
info "# DUMMY_COMMIT:         $DUMMY_COMMIT"
info "# DO_DB_INSERT:         $DO_DB_INSERT"
info "# DO_GIT:               $DO_GIT"
info "# ACTIVATE_ROOT_JOBS:   $ACTIVATE_ROOT_JOBS"
info "# DEVELOPER_BRANCH:     $DEVELOPER_BRANCH"
info "# DEBUG:                $DEBUG"
info "###############################################################"


SVN_REPO=$(getConfig branchingSvnServer)
SVN_DIR="os"
SRC_PROJECT="src-project"
VARS_FILE="VARIABLES.TXT"
GIT_REVISION_FILE=""

if [[ "${SRC_BRANCH}" == "trunk" ]]; then
    LOCATIONS="locations-pronb-developer"
    LOCATIONS_FSMR4="locations-FSM_R4_DEV"
    LOCATIONS_LRC="locations-LRC"
    SVN_PATH="${SVN_DIR}/trunk"
else
    LOCATIONS="locations-${SRC_BRANCH}"
    LOCATIONS_LRC="locations-LRC_${SRC_BRANCH}"
    LOCATIONS_FSMR4="locations-${SRC_BRANCH}_FSMR4"
    SVN_PATH="${SVN_DIR}/${SRC_BRANCH}/trunk"
    [[ $LRC == true ]] && SVN_PATH="${SVN_DIR}/LRC_${SRC_BRANCH}/trunk"
fi


__checkParams() {
    mustHaveValue "${SRC_BRANCH}" "SRC_BRANCH"
    mustHaveValue "${NEW_BRANCH}" "NEW_BRANCH"
    mustHaveValue "${REVISION}" "REVISION"
    mustHaveValue "${SOURCE_RELEASE}" "SOURCE_RELEASE"
    mustHaveValue "${ECL_URLS}" "ECL_URLS"
    mustHaveValue "${COMMENT}" "COMMENT"

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
    JOBS_EXCLUDE_LIST=$(getConfig branchingExcludeJobs)
    MAIN_BUILD_JOB_NAME_LRC=$(getConfig jenkinsMainBuildJobName_LRC)

    mustHaveValue "${MAIN_BUILD_JOB_NAME_LRC}" "MAIN_BUILD_JOB_NAME_LRC"
    mustHaveValue "${JENKINS_API_TOKEN}" "JENKINS_API_TOKEN"
    mustHaveValue "${JENKINS_API_USER}" "JENKINS_API_USER"

    echo JENKINS_API_TOKEN=${JENKINS_API_TOKEN} > ${WORKSPACE}/${VARS_FILE}
    echo JENKINS_API_USER=${JENKINS_API_USER} >> ${WORKSPACE}/${VARS_FILE}
    echo JOBS_EXCLUDE_LIST=${JOBS_EXCLUDE_LIST} >> ${WORKSPACE}/${VARS_FILE}
    echo MAIN_BUILD_JOB_NAME_LRC=${MAIN_BUILD_JOB_NAME_LRC} >> ${WORKSPACE}/${VARS_FILE}
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
    local branchLocation=$newBranch
    mustHaveValue "${locations}" "locations"
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    svn ls ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch} || {
            __cmd svn copy -m \"copy locations branch ${newBranch}\" ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/${locations} \
                ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch};
            __cmd svn checkout ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch};
            __cmd cd locations-${newBranch};
            if [[ $srcBranch == trunk || $srcBranch == LRC_trunk ]]; then
                __cmd sed -i -e "'s/\/os\/trunk\//\/os\/${branchLocation}\/trunk\//'" Dependencies;
            else
                __cmd sed -i -e "'s/\/os\/${srcBranch}\//\/os\/${branchLocation}\//'" Dependencies;
            fi
            __cmd svn commit -m \"added new location ${newBranch}.\";
            __cmd svn delete -m \"removed bldtools, because they are always used from MAINTRUNK\" ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk/bldtools;
    }
}

## @fn      svnCopyLocationsLRC()
#  @brief   just invokes "svnCopyLocations $1 $2 $3"
#  @param   <location> name of the location
#  @param   <srcBranch> name of the source branch
#  @param   <newBranch> name of the new branch
#  @return  <none>
svnCopyLocationsLRC() {
    svnCopyLocations $1 $2 $3
}

## @fn      svnCopyLocationsFSMR4()
#  @brief   just invokes "svnCopyLocations $1 $2 $3"
#  @param   <srcBranch> name of the source branch
#  @param   <newBranch> name of the new branch
#  @return  <none>
svnCopyLocationsFSMR4() {

    # Activate this as soon as FSMR4 has no extra handling.
    #svnCopyLocations $1 $2 $3

    if [[ ${FSMR4} != true ]]; then
        return 0
    fi

    info "--------------------------------------------------------"
    info "SVN: create locations for FSMR4"
    info "--------------------------------------------------------"

    local srcBranch=$1
    local newBranch=$2
    mustHaveValue "${srcBranch}" "source branch"
    mustHaveValue "${newBranch}" "new branch"

    svn ls ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4 || {
        __cmd svn copy -m \"copy locations branch ${newBranch}\" ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/${LOCATIONS_FSMR4} \
            ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4;
        __cmd svn checkout ${SVN_REPO}/${SVN_DIR}/trunk/bldtools/locations-${newBranch}_FSMR4;
        __cmd cd locations-${newBranch}_FSMR4;
        __cmd sed -i -e "'s/\/os\/${srcBranch}\//\/os\/${newBranch}\/trunk\//'" Dependencies;
        __cmd svn commit -m "added new location ${newBranch}_FSMR4.";
    }   
}

__getGitRevisionFile() {
    local branch=$1

    if [[ ${branch} == trunk && ${LRC} != true ]]; then
        branch="pronb-developer"
    elif [[ ${branch} == trunk && ${LRC} == true ]]; then
        branch=LRC
    elif [[ ${branch} != trunk && ${LRC} == true ]]; then
        branch=LRC_${branch}
    fi

    info "source branch for GIT revision file: $branch"
    local gitRevisionFile=$(getConfig PKGPOOL_PROD_update_dependencies_svn_url -t location:${branch})
    local replacement="src/gitrevision"

    if [[ "${gitRevisionFile}" == *Buildfile ]]; then
        gitRevisionFile="${gitRevisionFile/Buildfile/$replacement}"
    else
        gitRevisionFile="${gitRevisionFile/Dependencies/$replacement}"
    fi

    svn ls ${gitRevisionFile} && { info  "Git revision file: ${gitRevisionFile}"; } \
                              || { error "There is no git revision file: ${gitRevisionFile}."; exit 1; }

    GIT_REVISION_FILE=${gitRevisionFile}
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
        __getGitRevisionFile ${SRC_BRANCH}
        local gitRevisionFile=$GIT_REVISION_FILE
        mustHaveValue "${newBranch}" "new branch"
        mustHaveValue "${gitServer}" "git server"
        mustHaveValue "${gitRevisionFile}" "git revision file"

        __cmd svn cat -r ${REVISION} ${gitRevisionFile}
        gitRevision=$(svn cat -r ${REVISION} ${gitRevisionFile})
        info "GIT revision: ${gitRevision}"

        __cmd git clone ssh://git@${gitServer}/build/build
        __cmd cd build
        __cmd git branch $newBranch $gitRevision
        __cmd git push origin $newBranch
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

    __cmd svn checkout ${SVN_REPO}/${SVN_DIR}/${newBranch}/trunk/main/${SRC_PROJECT}
    if [[ -d ${SRC_PROJECT} ]]; then
        cd ${SRC_PROJECT}
        echo >> src/README
        __cmd svn commit -m \"dummy commit\" src/README
    fi
}

## @fn      svnDummyCommitLRC
#  @brief   perform a dummy commit in SVN for LRC
#  @param   <newBranch> new branch name
#  @return  <none>
svnDummyCommitLRC() {
    svnDummyCommit $1
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
    if [[ "${DEVELOPER_BRANCH}" == "true" ]]; then
        info "This is a developer branch."
        local regex="${branch}_PS_LFS_OS_20([0-9][0-9])_([0-9][0-9])_([0-9][0-9][0-9][0-9])"
    else
        local branchType=$(getBranchPart ${branch} TYPE)
        local yyyy=$(getBranchPart ${branch} YYYY)
        local mm=$(getBranchPart ${branch} MM)

        # Do we have a special branch?
        local subBranch=$(echo $branch | awk -F_ '{print $2}')
        [[ ${subBranch} ]] && branchType=${subBranch}
        local regex="${branchType}_PS_LFS_OS_${yyyy}_${mm}_([0-9][0-9][0-9][0-9])"

        if [[ ${LRC} == true ]]; then
            branch="LRC_${branch}"
            regex="${branchType}_LRC_LCP_PS_LFS_OS_${yyyy}_${mm}_([0-9][0-9][0-9][0-9])"
        fi
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
            svnCopyLocationsFSMR4 ${SRC_BRANCH} ${NEW_BRANCH}
            createBranchInGit ${NEW_BRANCH}
            svnDummyCommit ${NEW_BRANCH}
        elif [[ ${LRC} == "true" ]]; then
            svnCopyBranchLRC LRC_${SRC_BRANCH} LRC_${NEW_BRANCH}
            svnCopyLocationsLRC ${LOCATIONS_LRC} LRC_${SRC_BRANCH} LRC_${NEW_BRANCH}
            createBranchInGit LRC_${NEW_BRANCH}
            svnDummyCommitLRC LRC_${NEW_BRANCH}
        fi
    else
        info "$(basename $0): Nothing to do."
    fi

    dbInsert ${NEW_BRANCH}
}

main

