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

    execute ${LFS_CI_ROOT}/bin/svn_load_dirs.pl           \
                -v                                        \
                -t os/tag/${tagName}                      \
                -no_user_input                            \
                -message "upload"                         \
                -glob_ignores="#.#"                       \
                ${lfsDeliveryRepos} os/branches/${branch} \
                ${pathToUpload} 

    if [[ $? != 0 ]] ; then
        error "upload to svn failed"
        exit 1
    fi
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
