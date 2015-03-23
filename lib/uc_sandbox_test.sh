#!/bin/bash
## @file  uc_sandbox_test
#  @brief the sandbox test usecase

[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_database}  ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      usecase_LFS_CI_SANDBOX_TEST_TARGET_DUMMY()
#  @brief   only a dummy function for testing
#  @details dummy function that only add entries to db
#  @param   <none>
#  @return  <none>
usecase_LFS_CI_SANDBOX_TEST_TARGET_DUMMY() {                                                                                                                                                                       
    local workspace=$(getWorkspaceName)
	mustHaveWorkspaceName

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} 
    databaseEventSubTestStarted                                                                                                                                                                                    
    sleep $(( RANDOM % 120 ))                                                                                                                                                                                      
    databaseEventSubTestFinished                                                                                                                                                                                   
    mkdir ${workspace}/xml-reports/                                                                                                                                                                      
    cp ${LFS_CI_ROOT}/test/junitResult.xml ${workspace}/xml-reports/                                                                                                                                     
} 

