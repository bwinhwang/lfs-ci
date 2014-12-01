#!/bin/bash
# usecase for create a lfs knife build

# workflow
# * triggered via WFT 
# * runnins as a Jenkins project in LFS CI
#   - INPUT
#     - name of the requestor of the knife (username, email, real name)
#     - name of the branch in BTS_SC_LFS (opt)
#     - knife.zip (opt)
#     - knife request id (from WFT) (opt)
#     - base of the knife (baseline name)
#   - OUTPUT
#     - location (path on build share), where the LFS production is stored
#
# * create a workspace
#   - based on baseline name
#   - or on branch name from BTS_SC_LFS
#   - we can use the existing createWorkspace function, but we have to
#     fake the revision state file with the baseline name:
#     src-bos <url> <LABEL>
#     src-kernelsources <url> <LABEL>
#     ...


# Limitations
#  - only on branches, which are compartible with the new CI

# in Jenkins 
# * jobnames
#   - LFS_KNIFE_-_knife_-_Build
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fcmd
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fspc
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_qemu
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r3_-_fsm3_octeon2
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r3_-_qemu_64
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r4_-_fsm4_axm
#   - LFS_KNIFE_-_knife_-_Build_-_FSM-r4_-_fsm4_k2
#   - LFS_KNIFE_-_knife_-_Package_-_package

# Brain storming
# * we want to use as much code as possible from usecases build and package
# * we should think about to have a own configuation for a knife, which is overwriting the default values
#   (change in Config)
# * workspaces are unique
#   - /var/fpwork/${USER}/lfs-knife-workspaces/knifes.<dateTime>.<requestor>.<knifeId>
# * knife workspaces can be deleted after building (no matter if it is successful or not)

## @fn      ci_job_knife_build()
#  @brief   build a lfs knife
#  @param   <none>
#  @return  <none>
ci_job_knife_build() {

    # get the information from WFT (opt)
    # get the information from jenkins
    # create a workspace
    # build

    return 1
}

## @fn      ci_job_knife_package()
#  @brief   package a lfs knife
#  @param   <none>
#  @return  <none>
ci_job_knife_package() {
    return 1
}
