#!/bin/bash
## @file    uc_branching.sh
#  @brief   usecase branching
#  @details <none>


source ${LFS_CI_ROOT}/lib/common.sh

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
