#!/bin/bash
# @file   uc_admin_svn_clone.sh
# @detail This settings are only required for development CI
#         Idea: we have a clone of BTS_SC_LFS, which we can change without changing the real repos
#         But the clone is really big. If we want to recreate the repos, it will take a lot of time.
#         So we have a master clone, which is in sync with the real repos and a clone, which
#         can be changed by us. If we want to reset the clone, we "just" rsync the master to the clone.
#
# how to setup a clone:
# mkdir /tmp/svn
# cd /tmp/svn
# svnadmin create .
# mv hooks/pre-revprop-change.tmpl hooks/pre-revprop-change
# chmod 755 hooks/pre-revprop-change
# # edit hooks/pre-revprop-change and disable the error message and exit 1
# svnsync init \
#  file://${PWD}/ \
#  https://ulisop10.emea.nsn-net.net/isource/svnroot/BTS_SC_LFS
#  
# # will take a lot of time,
# # rerun the command to resync the repos to the latest revision
# svnsync sync file://${PWD}

## @fn      usecase_ADMIN_CLONE_SVN()
#  @brief   sync BTS_SC_LFS to our master directory
#  @param   <none>
#  @return  <none>
usecase_ADMIN_CLONE_SVN() {
    local svnCloneDirectory=$(getConfig ADMIN_lfs_svn_clone_master_directory)
    mustExistDirectory ${svnCloneDirectory}

    execute svnsync sync file://${svnCloneDirectory}/

    return
}

## @fn      usecase_ADMIN_RESTORE_SVN_CLONE()
#  @brief   restore the working copy from the master clone
#  @param   <none>
#  @return  <none>
usecase_ADMIN_RESTORE_SVN_CLONE() {
    local masterDirectory=$(getConfig ADMIN_lfs_svn_clone_master_directory)
    mustExistDirectory ${masterDirectory}
    local workingDirectory=$(getConfig ADMIN_lfs_svn_clone_working_directory)
    musHaveValue "${workingDirectory}" "svn clone working directory"

    execute mkdir -p ${workingDirectory}
    execute rsync --delete -avrP ${masterDirectory}/. ${workingDirectory}/.

    return
}
