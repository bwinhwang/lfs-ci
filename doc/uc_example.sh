#!/bin/bash

## @fn      usecase_LFS_EXAMPLE_USECASE(  )
#  @brief   execute the example lfs usecase
#  @details in the jenkins job configuration, you have to define a environment
#           variable LFS_CI_GLOBAL_USECASE with the value LFS_EXAMPLE_USECASE
#  @param   <none>
#  @return  <none>
usecase_LFS_EXAMPLE_USECASE() {
    requiredParameters LFS_CI_ROOT

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    doSomeFancyStuff

    return
}

