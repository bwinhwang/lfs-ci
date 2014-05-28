#!/bin/bash

## @fn      uploadToSubversion( $pathToUpload, $branchToUpload, $commitMessage )
#  @brief   uploads a directory to the specified svn location and commit it
#  @details this method upload a directory to subversion using the script svn_load_dirs.pl
#           which is part of the subversion source package.
#  @param   {pathToUpload}    path names, which contains the files to upload to svn
#  @param   {branchToUpload}  svn location where the files should be uploaded
#  @param   {commitMessage}   commit message
#  @return  <none>
uploadToSubversion() {

    requiredParameters LFS_CI_ROOT

    local pathToUpload=$1
    local branchToUpload=$2
    local commitMessage="$3"

    local svnReposUrl=$(getConfig lfsDeliveryRepos)

    info "upload local path ${pathToUpload} to ${branchToUpload}"

    local branch=${locationToSubversionMap["${branchToUpload}"]}
    if [[ ! "${branch}" ]] ; then
        DEBUG "mapping for branchToUpload ${branchToUpload} not found"
        branch=${branchToUpload}
    fi
    local oldTemp=${TMPDIR}
    export TMPDIR=${WORKSPACE}/tmp/
    mkdir -p ${TMPDIR}

    mustHaveNextLabelName
    local tagName=$(getNextReleaseLabel)

    local branchPath=$(getConfig SVN_branch_path_name)
    local tagPath=$(getConfig SVN_tag_path_name)
    mustHaveValue "${tagPath}"
    mustHaveValue "${branchPath}"

    info ${LFS_CI_ROOT}/bin/svn_load_dirs.pl        \
                -v                                     \
                -t ${tagPath}/${tagName}               \
                -no_user_input                         \
                -message "upload"                      \
                -glob_ignores="#.#"                    \
                ${svnReposUrl} ${branchPath}/${branch} \
                ${pathToUpload} 
#    execute ${LFS_CI_ROOT}/bin/svn_load_dirs.pl        \
#                -v                                     \
#                -t ${tagPath}/${tagName}               \
#                -no_user_input                         \
#                -message "upload"                      \
#                -glob_ignores="#.#"                    \
#                ${svnReposUrl} ${branchPath}/${branch} \
#                ${pathToUpload} 

    export TMPDIR=${oldTemp}

    return
}

## @fn      svnCommand( $args )
#  @brief   execute the given subversion command with the specified parameters
#  @param   {args}    command and arguments of the svn command
#  @return  <none>
svnCommand() {
    local args=$@
    debug "executing svn $@"
    execute svn --non-interactive --trust-server-cert $@
    return
}

## @fn      svnCheckout( $args )
#  @brief   check out a repository
#  @param   {args}  args for the svn co command
#  @return  <none>
svnCheckout() {
    svnCommand checkout $@
    return
}

## @fn      svnCommit( $args )
#  @brief   executes an svn commit command
#  @param   {args}    args for the svn commit command
#  @return  <none>
svnCommit() {
    svnCommand commit $@
    return
}

## @fn      svnDiff( $args )
#  @brief   executes an svn diff command
#  @param   {args}    args for the svn diff command
#  @return  <none>
svnDiff() {
    svnCommand diff $@
    return
}

svnExistsPath() {
    return
}
