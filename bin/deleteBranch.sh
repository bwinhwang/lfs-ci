#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh

initTempDirectory

SVN_REPO=$(getConfig branchingSvnUrl)
SVN_DIR="os"
SVN_BLD_DIR="trunk/bldtools"
SHARE="/build/home/CI_LFS/Release_Candidates"
BLD_SHARE="/build/home/SC_LFS/releases/bld"
PKG_SHARE="/build/home/SC_LFS/pkgpool"
SVN_OPTS="--non-interactive --trust-server-cert"
ARCHIVE_BASE=$(getConfig ADMIN_archive_share)
VARS_FILE="VARIABLES.TXT"
DIR_PATTERN=""
ARCHIVE_RESULT=0
SVN_RESULT_MOVE_BRANCH_LOCATION=0
SVN_RESULT_MOVE_BRANCH_LOCATION_FSMR4=0
SVN_RESULT_MOVE_BRANCH=0
LRC_SVN_RESULT_MOVE_BRANCH_LOCATION=0
LRC_SVN_RESULT_MOVE_BRANCH=0
DB_UPDATE_RESULT1=0
DB_UPDATE_RESULT2=0

__printParams() {
    info "###############################################################"
    info "# Variables from Jenkins"
    info "# ----------------------"
    info "# BRANCH:              $BRANCH"
    info "# MOVE_SVN:            $MOVE_SVN"
    info "# DELETE_JOBS:         $DELETE_JOBS"
    info "# DELETE_TEST_RESULTS: $DELETE_TEST_RESULTS"
    info "# MOVE_SHARE:          $MOVE_SHARE"
    info "# LRC_MOVE_SVN:        $LRC_MOVE_SVN"
    info "# LRC_DELETE_JOBS:     $LRC_DELETE_JOBS"
    info "# LRC_MOVE_SHARE:      $LRC_MOVE_SHARE"
    info "# DB_UPDATE:           $DB_UPDATE"
    info "# DEVELOPER_BRANCH:    $DEVELOPER_BRANCH"
    info "# DEBUG:               $DEBUG"
    info "# COMMENT:             $COMMENT"
    info "###############################################################"
}

## @fn      getValueFromEclFile()
#  @brief   get value from ecl for key
#  @param   {key} the key in the ECL file
#  @param   {branch} the branch
#  @return  <none>
getValueFromEclFile() {
    local key=$1
    local branch=$2
    local svnEclRepo=$(echo ${SVN_REPO} | awk -F/ '{print $1"//"$2$3}')

    svn ls ${SVN_OPTS} ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/${branch}/ECL_BASE/ECL 2> /dev/null
    if [[ $? -eq 0 ]]; then
        local value=$(svn cat ${SVN_OPTS} ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/${branch}/ECL_BASE/ECL | grep ${key} | cut -d'=' -f2)
    else
        info "using ECL from obsolete"
        local value=$(svn cat ${SVN_OPTS} ${svnEclRepo}/isource/svnroot/BTS_SCM_PS/ECL/obsolete/${branch}/ECL_BASE/ECL | grep ${key} | cut -d'=' -f2)
    fi

    echo ${value}
}


#######################################################################
#
# HELPER FUNCTIONS
#
#######################################################################


__checkParams() {
    [[ ! "${BRANCH}" ]] && { error "BRANCH must be specified"; return 1; }

    if [[ $DEVELOPMENT_BRANCH == false ]]; then
        echo ${BRANCH} | grep -q -e "^FB[0-9]\{4\}\|^MD[0-9]\{5\}\|^LRC_FB[0-9]\{4\}\|^TST_\|TEST_ERWIN\|TESTERWIN" || { error "$BRANCH is not valid."; return 1; }
    fi

    if [[ $LRC == true ]]; then
        echo ${BRANCH} | grep -q -e "^LRC_" || { error "LRC: Branch name is not correct."; return 1; }
    else
        echo ${BRANCH} | grep -q -e "^LRC_" && { error "FSM: Branch name is not correct."; return 1; }
    fi

    return 0
}

__checkOthers() {
    which mysql > /dev/null 2>&1 || { error "mysql not available."; return 1; }
}

__cmd() {
    if [[ $DEBUG == true ]]; then
        debug $@
        echo [DEBUG] $@
    else
        info runnig command: $@
        eval $@
    fi
    return $?
}

## @fn     __preparation()
#  @brief  Create key=value pairs file which is sourced by Jenkins.
__preparation(){
    JENKINS_JOBS_DIR=$(getConfig jenkinsMasterServerJobsPath)
    mustHaveValue "${JENKINS_JOBS_DIR}" "JENKINS_JOBS_DIR"
    echo JENKINS_JOBS_DIR=${JENKINS_JOBS_DIR} >> ${WORKSPACE}/${VARS_FILE}
    
    mustHaveValue "${ARCHIVE_BASE}" "ARCHIVE_BASE"
    if [[ ! -d ${ARCHIVE_BASE} ]]; then
        info "create archive share ${ARCHIVE_BASE}"
        __cmd mkdir -p ${ARCHIVE_BASE}
    fi
}

__getSubBranch() {
    local branch=$1
    echo ${branch} | grep -q '_'
    if [[ $? -ne 0 ]]; then
        echo ""
    else
        local subBranch=$(echo ${branch} | cut -d'_' -f2)
        echo ${subBranch}
    fi
}

#######################################################################
#
# WORKING FUNCTIONS
#
#######################################################################

## @fn      moveBranchLocationSvn()
#  @brief   move locations for $BRANCH in svn
#  @param   <none>
#  @return  <none>
moveBranchLocationSvn() {
    info "--------------------------------------------------------"
    info "SVN: move locations and FSMr4 in SVN"
    info "--------------------------------------------------------"

    svn ls ${SVN_OPTS} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved locations-${BRANCH} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
        SVN_RESULT_MOVE_BRANCH_LOCATION=$?;
    }

    svn ls ${SVN_OPTS} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved locations-${BRANCH} FSMR4 to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${BRANCH}_FSMR4 ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
        SVN_RESULT_MOVE_BRANCH_LOCATION_FSMR4=$?;
    }
}

## @fn      moveBranchSvn()
#  @brief   move the $BRANCH in svn
#  @param   <none>
#  @return  <none>
moveBranchSvn() {
    info "--------------------------------------------------------"
    info "SVN: move os/${BRANCH} in SVN"
    info "--------------------------------------------------------"

    svn ls ${SVN_OPTS} ${SVN_REPO}/${SVN_DIR}/${BRANCH} 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved ${BRANCH} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${BRANCH} ${SVN_REPO}/${SVN_DIR}/obsolete;
        SVN_RESULT_MOVE_BRANCH=$?;
    }
}

## @fn      LRC_moveBranchSvn()
#  @brief   move $BRANCH in svn for LRC
#  @param   <none>
#  @return  <none>
LRC_moveBranchSvn() {
    info "--------------------------------------------------------"
    info "SVN: move branch in SVN for LRC"
    info "--------------------------------------------------------"

    local branch="${BRANCH}"
    svn ${SVN_OPTS} ls ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${branch} 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved locations-${branch} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/locations-${branch} ${SVN_REPO}/${SVN_DIR}/${SVN_BLD_DIR}/obsolete;
        LRC_SVN_RESULT_MOVE_BRANCH_LOCATION=$?;
    }

    svn ls ${SVN_OPTS} ${SVN_REPO}/${SVN_DIR}/${branch} 2> /dev/null && {
        __cmd svn ${SVN_OPTS} move -m \"moved ${branch} to obsolete\" \
            ${SVN_REPO}/${SVN_DIR}/${branch} ${SVN_REPO}/${SVN_DIR}/obsolete;
        LRC_SVN_RESULT_MOVE_BRANCH=$?;
    }

    return 0
}

_getDirPattern() {
    local branch=$1
    local dbName=$(getConfig MYSQL_db_name)
    local dbUser=$(getConfig MYSQL_db_username)
    local dbPass=$(getConfig MYSQL_db_password)
    local dbHost=$(getConfig MYSQL_db_hostname)
    local dbPort=$(getConfig MYSQL_db_port)
    local sqlString="SELECT release_name_regex FROM branches WHERE branch_name='${branch}'"
    local dirPattern=$(echo "${sqlString}" | mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName} 2> /dev/null)
    mustHaveValue "${dirPattern}" "dirPattern"

    dirPattern=$(echo ${dirPattern} | cut -d'(' -f1)
    DIR_PATTERN="${dirPattern}*"

    if [[ "$DIR_PATTERN" == "*" || ${#DIR_PATTERN} -lt 20 ]]; then
        error "Invalid directory pattern: $DIR_PATTERN"
        exit 1
    fi 
}

## @fn      archiveShare()
#  @brief   archive (move) data on share
#  @param   {share}    the share directory to be archived
#  @param   {findDepth}    value for -maxdepth parameter of find. Possible values are 1 or 2. Defaults to 2
#  @return  <none>
archiveShare() {
    info "--------------------------------------------------------"
    info "ARCHIVE: archiving share ${1}"
    info "--------------------------------------------------------"

    _getDirPattern ${BRANCH}

    local shareToArchive=$1
    local findDepth=2
    if [[ ! -z $2 ]]; then
        local re='^[12]$'
        [[ ! $2 =~ $re ]] && { error "\$2 must be 1 or 2"; exit 1; }
        findDepth=${2}
    fi
    local dirPattern=$DIR_PATTERN

    if [[ ! -d ${shareToArchive} ]]; then
        ARCHIVE_RESULT=1
        return 0
    fi

    local dirsToDelete=$(find ${shareToArchive} -maxdepth ${findDepth} -type d -name "${dirPattern}")
    info "archive ${shareToArchive}"
    info "directory pattern: ${dirPattern}"
    for DIR in ${dirsToDelete}
    do
        local archiveDir=$(echo $DIR | sed 's/\//_/g')
        __cmd mv ${DIR} ${ARCHIVE_BASE}/${archiveDir}
        local retVal=$?
        [[ ${retVal} -ne 0 && ${ARCHIVE_RESULT} -eq 0 ]] && ARCHIVE_RESULT=${retVal}
    done
}

archiveBranchShare() {
    archiveShare ${SHARE}
}

## @fn      archiveBranchBldShare()
#  @brief   archive data for BRANCH on bld share
#  @param   <none>
#  @return  <none>
archiveBranchBldShare() {
    archiveShare ${BLD_SHARE}
}

## @fn      archiveBranchPkgShare()
#  @brief   archive data for BRANCH on pkgpool share
#  @param   <none>
#  @return  <none>
archiveBranchPkgShare() {

    # Not yet used.

    archiveShare ${PKG_SHARE} 1
}

## @fn      LRC_archiveBranchShare()
#  @brief   archive date for BRANCH on share for LRC
#  @param   <none>
#  @return  <none>
LRC_archiveBranchShare() {
    archiveShare ${SHARE}
}

## @fn      LRC_archiveBranchBldShare()
#  @brief   archive date for BRANCH on bld share for LRC
#  @param   <none>
#  @return  <none>
LRC_archiveBranchBldShare() {
    archiveShare ${BLD_SHARE}
}

deleteTestResults() {
    info "--------------------------------------------------------"
    info "TESTS: deleteTestResults()"
    info "--------------------------------------------------------"

    _getDirPattern ${BRANCH}

    local subBranch=$(__getSubBranch ${BRANCH})
    local dirPattern=$DIR_PATTERN
    if [[ "${subBranch}" != "" ]]; then
        info "sub branch: ${subBranch}"
    else
        yyyy=$(getBranchPart ${BRANCH} YYYY)
        mm=$(getBranchPart ${BRANCH} MM)
        branchType=$(getBranchPart ${BRANCH} TYPE)
        echo ${dirPattern} | grep -q ${branchType}_PS_LFS_OS_${yyyy}_${mm} || { echo ${branchType}_PS_LFS_OS_${yyyy}_${mm} is not in directory pattern ${dirPattern}; exit 1; }
    fi

    local testServer=$(getConfig LFS_CI_testresults_host)
    local testResultsDir=$(getConfig LFS_CI_testresults_dir)

    mustHaveValue "${testServer}" "testServer"
    mustHaveValue "${testResultsDir}" "testResultsDir"

    if [[ ! ${testResultsDir} == */ ]]; then
        testResultsDir=${testResultsDir}/
    fi

    __cmd ssh ${testServer} rm -rf ${testResultsDir}${dirPattern}
}

## @fn      dbUpdate()
#  @brief   set branch to closed in DB
#  @param   <branch> the name of the branch
#  @return  <none>
dbUpdate() {
    info "--------------------------------------------------------"
    info "DB: update branch to closed in lfspt database"
    info "--------------------------------------------------------"

    local branch=${BRANCH}
    local sqlString1="UPDATE branches SET status='closed',date_closed=now() WHERE branch_name='${branch}' AND status!='closed'"
    local sqlString2="UPDATE ps_branches SET status='closed' WHERE ps_branch_name='${branch}' AND status!='closed'"

    local dbName=$(getConfig MYSQL_db_name)
    local dbUser=$(getConfig MYSQL_db_username)
    local dbPass=$(getConfig MYSQL_db_password)
    local dbHost=$(getConfig MYSQL_db_hostname)
    local dbPort=$(getConfig MYSQL_db_port)

    if [[ $DEBUG == true ]]; then
        debug $sqlString1
        echo [DEBUG] $sqlString1
        debug $sqlString2
        echo [DEBUG] $sqlString2
    else
        info "updating DB: $sqlString1"
        echo $sqlString1 | mysql -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName} 2> /dev/null
        DB_UPDATE_RESULT1=$?
        info "updating DB: $sqlString2"
        echo $sqlString2 | mysql -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName} 2> /dev/null
        DB_UPDATE_RESULT2=$?
    fi
}


#######################################################################
# main
#######################################################################

main() {

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${BRANCH} DEBUG=${DEBUG}"

    __printParams
    __checkParams || { error "Params check failed."; exit 1; }
    __checkOthers || { error "Checking some stuff failed."; exit 1; }
    __preparation

    [[ ${DB_UPDATE} == true ]] && dbUpdate || info "Not updating DB."

    if [[ $LRC == true ]]; then
        [[ ${LRC_MOVE_SVN} == true ]] && LRC_moveBranchSvn
        [[ ${LRC_MOVE_SHARE} == true ]] && { LRC_archiveBranchShare; LRC_archiveBranchBldShare; }
    else
        [[ ${MOVE_SVN} == true ]] && { moveBranchLocationSvn; moveBranchSvn; }
        [[ ${MOVE_SHARE} == true ]] && { archiveBranchShare; archiveBranchBldShare; }
        [[ ${DELETE_TEST_RESULTS} == true ]] && deleteTestResults
    fi

    local result=$((${ARCHIVE_RESULT}+\
                    ${SVN_RESULT_MOVE_BRANCH_LOCATION}+\
                    ${SVN_RESULT_MOVE_BRANCH_LOCATION_FSMR4}+\
                    ${SVN_RESULT_MOVE_BRANCH}+\
                    ${LRC_SVN_RESULT_MOVE_BRANCH_LOCATION}+\
                    ${LRC_SVN_RESULT_MOVE_BRANCH}+\
                    ${DB_UPDATE_RESULT1}+\
                    ${DB_UPDATE_RESULT2}))

    if [[ ${result} -ne 0 ]]; then
        echo ""
        error "One of the following failed:"
        info "ARCHIVE_RESULT: ${ARCHIVE_RESULT}"
        info "SVN_RESULT_MOVE_BRANCH_LOCATION: ${SVN_RESULT_MOVE_BRANCH_LOCATION}"
        info "SVN_RESULT_MOVE_BRANCH_LOCATION_FSMR4: ${SVN_RESULT_MOVE_BRANCH_LOCATION_FSMR4}"
        info "SVN_RESULT_MOVE_BRANCH: ${SVN_RESULT_MOVE_BRANCH}"
        info "LRC_SVN_RESULT_MOVE_BRANCH_LOCATION: ${LRC_SVN_RESULT_MOVE_BRANCH_LOCATION}"
        info "LRC_SVN_RESULT_MOVE_BRANCH: ${LRC_SVN_RESULT_MOVE_BRANCH}"
        info "DB_UPDATE_RESULT1: ${DB_UPDATE_RESULT1}"
        info "DB_UPDATE_RESULT2: ${DB_UPDATE_RESULT2}"
        echo ""
        setBuildResultUnstable
    fi

    return 0
}

if [[ ! $TESTING ]]; then
    main
fi

