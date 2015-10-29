#!/bin/bash
## @file    uc_branching.sh
#  @brief   usecase for creating/deleting a branch
#  @details <none>


source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/database.sh

## @fn      createBranch()
#  @brief   create a LFS branch
#  @param   <none>
#  @retrun  <none>
usecase_LFS_BRANCHING_CREATE_BRANCH() {
    ${LFS_CI_ROOT}/bin/createBranch.sh
}

## @fn      deleteBranch()
#  @brief   delete a LFS branch
#  @param   <none>
#  @retrun  <none>
usecase_LFS_BRANCHING_DELETE_BRANCH() {
    ${LFS_CI_ROOT}/bin/deleteBranch.sh
}

usecase_LFS_BRANCHING_MD_FOR_LRC() {
    mustHaveDatabaseCredentials
    mustHaveValue ${BRANCH} "BRANCH is missing"
    mustHaveValue ${PS_BRANCH} "PS_BRANCH is missing"
    mustHaveValue ${ACTION} "ACTION is missing"
    [[ ! ${BRANCH} =~ ^LRC_ ]] && BRANCH=LRC_${BRANCH}
    case ${ACTION} in
        create)
            info "Insert new branch into tables branches and ps_branches."
            echo "CALL new_ps_branch_for_md_lrc('"${BRANCH}"', '"${PS_BRANCH}"', '"${ECL_URL}"')" / ${mysql_cli} -Dlfspt_lrc
            #echo "CALL new_ps_branch_for_md_lrc('"${BRANCH}"', '"${PS_BRANCH}"', '"${ECL_URL}"')" | ${mysql_cli} -Dlfspt_lrc
        ;;
        close)
            info "Close branch in tables branches and ps_branches."
            echo "CALL close_ps_branch_for_md_lrc('"${PS_BRANCH}"')" / ${mysql_cli} -Dlfspt_lrc
            #echo "CALL close_ps_branch_for_md_lrc('"${PS_BRANCH}"')" | ${mysql_cli} -Dlfspt_lrc
        ;;
    esac
}
