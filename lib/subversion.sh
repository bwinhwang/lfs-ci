#!/bin/bash

LFS_CI_SOURCE_subversion='$Id$'

## @fn      uploadToSubversion( $pathToUpload, $branchToUpload, $commitMessage )
#  @brief   uploads a directory to the specified svn location and commit it
#  @details this method upload a directory to subversion using the script svn_load_dirs.pl
#           which is part of the subversion source package.
#  @param   {pathToUpload}    path names, which contains the files to upload to svn
#  @param   {branchToUpload}  svn location where the files should be uploaded
#  @param   {commitMessage}   commit message
#  @return  <none>
uploadToSubversion() {
    requiredParameters LFS_CI_ROOT TMPDIR

    local pathToUpload=$1
    local branchToUpload=$2
    local commitMessage="$3"

    local svnReposUrl=$(getConfig lfsOsDeliveryRepos)

    info "upload local path ${pathToUpload} to ${branchToUpload}"

    local branch=${locationToSubversionMap["${branchToUpload}"]}
    # local branch=$(getConfig LFS_PROD_subversion_upload_branch_name)
    if [[ ! "${branch}" ]] ; then
        debug "mapping for branchToUpload ${branchToUpload} not found"
        branch=${branchToUpload}
    fi

    info "upload to ${branch}"

    local oldTemp=${TMPDIR}
    export TMPDIR=${WORKSPACE}/tmp/
    debug "cleanup tmp directory"
    rm -rf ${TMPDIR}
    mkdir -p ${TMPDIR}

    mustHaveNextLabelName
    local tagName=$(getNextReleaseLabel)

    local branchPath=$(getConfig SVN_branch_path_name)
    local tagPath=$(getConfig SVN_tag_path_name)
    mustHaveValue "${tagPath}" "tag path"
    mustHaveValue "${branchPath}" "branch path"

    info "upload to svn and create copy (${tagName})"

    execute ${LFS_CI_ROOT}/bin/svn_load_dirs.pl        \
                -v                                     \
                -t ${tagPath}/${tagName}               \
                -no_user_input                         \
                -glob_ignores="#.#"                    \
                ${svnReposUrl} ${branchPath}/${branch} \
                ${pathToUpload} 

#                -message "upload"                      \

    export TMPDIR=${oldTemp}
    info "upload done";

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
    local args=
    while [[ ! -z $@ ]] ; do args="${args} '$1'" ; shift; done
    svnCommand checkout ${args}
    return
}

## @fn      svnCommit( $args )
#  @brief   executes an svn commit command
#  @param   {args}    args for the svn commit command
#  @return  <none>
svnCommit() {
    local args=
    while [[ ! -z $@ ]] ; do args="${args} '$1'" ; shift; done
    svnCommand commit ${args}
    return
}

## @fn      svnMkdir( $args )
#  @brief   executes an svn mkdir command
#  @param   {args}    args for the svn mkdir command
#  @return  <none>
svnMkdir() {
    local args=
    while [[ ! -z $@ ]] ; do args="${args} '$1'" ; shift; done
    svnCommand mkdir ${args}
    return
}

## @fn      svnCopy( $args )
#  @brief   executes an svn copy command
#  @param   {args}    args for the svn copy command
#  @return  <none>
svnCopy() {
    local args=
    while [[ ! -z $@ ]] ; do args="${args} '$1'" ; shift; done
    svnCommand copy ${args}
    return
}

## @fn      svnDiff( $args )
#  @brief   executes an svn diff command
#  @param   {args}    args for the svn diff command
#  @return  <none>
svnDiff() {
    local args=
    while [[ ! -z $@ ]] ; do args="${args} '$1'" ; shift; done
    svnCommand diff ${args}
    return
}

## @fn      svnPropSet( $args )
#  @brief   executes an svn propset command
#  @param   {args}    args for the svn propset command
#  @return  <none>
svnPropSet() {
    local args=
    while [[ ! -z $@ ]] ; do args="${args} '$1'" ; shift; done
    svnCommand propset ${args}
    return
}

## @fn      svnRemove( $args )
#  @brief   executes an svn remove command
#  @param   {args}    args for the svn remove command
#  @return  <none>
svnRemove() {
    local args=
    while [[ ! -z $@ ]] ; do args="${args} '$1'" ; shift; done
    svnCommand rm ${args}
    return
}

## @fn      shouldNotExistsInSubversion( $url, $pathOrFile )
#  @brief   checks, if the path/file exists in svn 
#  @detail  if you want to check http://server/path/to/repos/foo, the
#           input url is:  http://server/path/to/repos
#           input path is: foo
#  @param   {url}           a svn url (dirname only)
#  @param   {pathOrFIle}    a path / file elemnt of the path
#  @throws  raise an error if the url exists
shouldNotExistsInSubversion() {
    local url=$1
    local tag=$2

    if existsInSubversion ${url} ${tag} ; then
        error "entry ${tag} exists in ${url}"
        exit 1
    fi
    return 0
}

## @fn      existsInSubversion( $url, $pathOrFile )
#  @brief   checks, if the path/file exists in svn 
#  @detail  if you want to check http://server/path/to/repos/foo, the
#           input url is:  http://server/path/to/repos
#           input path is: foo
#  @param   {url}           a svn url (dirname only)
#  @param   {pathOrFIle}    a path / file elemnt of the path
#  @return  1 if it exists, otherwise 0
existsInSubversion() {
    local url=$1
    local tag=$2
    local tmp=$(createTempFile)

    svn ls --xml ${url} | ${LFS_CI_ROOT}/bin/xpath -q -e /lists/list/entry/name > ${tmp}
    if [[ $? != 0 ]] ; then
        error "svn ls failed"
        exit 1
    fi

    if grep -q "<name>${tag}</name>" ${tmp} ; then
        return 0
    fi

    return 1
}

## @fn      mustExistInSubversion( $url, $pathOrFile )
#  @brief   ensure, that the path/file exists in svn 
#  @detail  if you want to check http://server/path/to/repos/foo, the
#           input url is:  http://server/path/to/repos
#           input path is: foo
#  @param   {url}           a svn url (dirname only)
#  @param   {pathOrFIle}    a path / file elemnt of the path
#  @throws  raise an error, if it not exists
mustExistInSubversion() {
    local url=$1
    local tag=$2

    if ! existsInSubversion ${url} ${tag} ; then
        error "entry ${tag} exists in ${url}"
        exit 1
    fi

    return 0
}
mustExistBranchInSubversion() {
    local url=$1
    local branch=$2

    if ! existsInSubversion ${url} ${branch} ; then
        svnMkdir -m new_branch ${url}/${branch}
    fi

    return 0
}

## @fn      getSvnUrl( $url )
#  @brief   get the svn url for a svn url
#  @details hae? why url from a url? Cause the url can be also a location in the filesystem
#           input url: /path/to/workspace
#           output url: https://master/path/to/repos/
#  @param   {url}    a svn url
#  @return  a svn url
getSvnUrl() {
    local url=$1
    getSvnInfo ${url} '/info/entry/url/node()'
    return
}

## @fn      getSvnRevision( $url )
#  @brief   get the revision for a svn url
#  @param   {url}    a svn url
#  @return  the svn revision
getSvnRevision() {
    local url=$1
    getSvnInfo ${url} "/info/entry/@revision" | cut -d'"' -f2
    return
}

## @fn      getSvnLastChangedRevision( $url )
#  @brief   get the last changed revision for a svn url
#  @param   {url}    a svn url
#  @return  the last changed revision 
getSvnLastChangedRevision() {
    local url=$1
    getSvnInfo ${url} "/info/entry/commit/@revision" | cut -d'"' -f2
    return
}

## @fn      getSvnInfo( $url, $xmlPath )
#  @brief   get a specific information out of the svn info output for a svn url
#  @param   {url}      a svn url
#  @param   {xmlPath}  a xml path, e.g. /info/entry/commit/@revision for last changed revision   
#  @return  the information from svn info
getSvnInfo() {
    local url=$1
    local xmlPath=$2
    local tmpFile=$(createTempFile)

    svn info --xml ${url} > ${tmpFile}
    mustBeSuccessfull "$?" "svn info ${url}"

    ${LFS_CI_ROOT}/bin/xpath -q -e ${xmlPath} ${tmpFile}
    mustBeSuccessfull "$?" "xmlPath -q -e ${xmlPath}"

    return
}

## @fn      normalizeSvnUrl( $url )
#  @brief   normalize a svn url, replace the hostname with the master server host name
#  @param   {url}    a svn url
#  @return  a normalized (master server) svn url
normalizeSvnUrl() {
    local url=$1
    local masterHostname=$(getConfig svnMasterServerHostName)

    local currentHostname=$(cut -d/ -f3 <<< ${url})

    if [[ ${currentHostname} ]] ; then
        url=$(sed "s/${currentHostname}/${masterHostname}/g" <<< ${url})
    fi

    echo ${url}

    return
}
