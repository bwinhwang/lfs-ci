#!/bin/bash
## @file    subversion.sh
#  @brief   common subversion wrapper functions
#  @details functions which makes the handling of subversion a little bit
#           simplier.

LFS_CI_SOURCE_subversion='$Id$'

## @fn      uploadToSubversion()
#  @brief   uploads a directory to the specified svn location and commit it
#  @details this method upload a directory to subversion using the script svn_load_dirs.pl
#           which is part of the subversion source package.
#  @param   {pathToUpload}    path names, which contains the files to upload to svn
#  @param   {branchToUpload}  svn location where the files should be uploaded
#  @param   {commitMessage}   commit message
#  @return  <none>
uploadToSubversion() {
    requiredParameters LFS_CI_ROOT JOB_NAME USER

    local pathToUpload=$1
    local branchToUpload=$2
    local commitMessage="$3"

    # fsmci artifact file is already copied to workspace by upper function
    mustHaveNextLabelName
    export tagName=$(getNextReleaseLabel)

    local svnReposUrl=$(getConfig LFS_PROD_svn_delivery_release_repos_url)

    info "upload local path ${pathToUpload} to ${branchToUpload} as ${tagName}"

    local branch=$(getConfig LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch)
    if [[ ! "${branch}" ]] ; then
        debug "mapping for branchToUpload ${branchToUpload} not found"
        branch=${branchToUpload}
    fi

    info "upload to ${branch}"

    local branchPath=os/branches
    local tagPath=os/tags
    mustHaveValue "${tagPath}" "tag path"
    mustHaveValue "${branchPath}" "branch path"

    mustExistBranchInSubversion ${svnReposUrl} os
    mustExistBranchInSubversion ${svnReposUrl}/os branches
    mustExistBranchInSubversion ${svnReposUrl}/os tags
    mustExistBranchInSubversion ${svnReposUrl}/os/branches "${branch}"

    local oldTemp=${TMPDIR:-/tmp}
    export TMPDIR=/dev/shm/${JOB_NAME}.${USER}/tmp
    debug "cleanup tmp directory"
    execute mkdir -p ${TMPDIR}

    # ensure, that there are 15 GB disk space
    mustHaveFreeDiskSpace ${TMPDIR} 15000000 

    # ensure, that there are 15 GB disk space
    mustHaveFreeDiskSpace ${TMPDIR} 15000000 

    # TMPDIR is not handled/created via createTempDirectory. So we have to
    # take care to clean up the temp directory after exit and failure
    exit_add subversionUploadCleanupTempDirectory

    rm -rf ${TMPDIR}
    mkdir -p ${TMPDIR}
    
    info "copy baseline to upload on local disk"
    local uploadDirectoryOnLocalDisk=${TMPDIR}/upload
    execute mkdir -p ${uploadDirectoryOnLocalDisk}
    execute rsync --delete -av ${pathToUpload}/ ${uploadDirectoryOnLocalDisk}/

    local workspace=${TMPDIR}/workspace
    if [[ ! -d ${workspace} ]] ; then
        info "checkout svn workspace for upload preparation"
        execute mkdir -p ${workspace}
        svnCheckout ${svnReposUrl}/${branchPath}/${branch} ${workspace}
    fi

    info "upload to svn and create copy (${tagName})"

    execute -r 3 \
                ${LFS_CI_ROOT}/bin/svn_load_dirs.pl    \
                -v                                     \
                -t ${tagPath}/${tagName}               \
                -wc ${workspace}                       \
                -no_user_input                         \
                -no_diff_tag                           \
                -glob_ignores="#.#"                    \
                -sleep 60                              \
                ${svnReposUrl} ${branchPath}/${branch} \
                ${uploadDirectoryOnLocalDisk} 

    export TMPDIR=${oldTemp}
    info "upload done";

    return
}

## @fn      subversionUploadCleanupTempDirectory()
#  @brief   cleanup the created temp directory in svn upload function
#  @param   <none>
#  @return  <none>
subversionUploadCleanupTempDirectory() {
    requiredParameters JOB_NAME USER

    local tmpDirectory=/dev/shm/${JOB_NAME}.${USER}
    [[ -d ${tmpDirectory} ]] && rm -rf ${tmpDirectory}

    return
}

## @fn      svnCommand()
#  @brief   execute the given subversion command with the specified parameters
#  @param   {args}    command and arguments of the svn command
#  @return  <none>
svnCommand() {
    debug "executing svn $@"
    execute -r 3 svn --non-interactive --trust-server-cert $@
    return
}

## @fn      svnCheckout()
#  @brief   check out a repository
#  @param   {args}  args for the svn co command
#  @return  <none>
svnCheckout() {
    svnCommand checkout $@
    return
}

## @fn      svnCommit()
#  @brief   executes an svn commit command
#  @param   {args}    args for the svn commit command
#  @return  <none>
svnCommit() {
    svnCommand commit $@
    return
}

## @fn      svnMkdir()
#  @brief   executes an svn mkdir command
#  @param   {args}    args for the svn mkdir command
#  @return  <none>
svnMkdir() {
    svnCommand mkdir $@
    return
}

## @fn      svnCopy()
#  @brief   executes an svn copy command
#  @param   {args}    args for the svn copy command
#  @return  <none>
svnCopy() {
    svnCommand copy $@
    return
}

## @fn      svnDiff()
#  @brief   executes an svn diff command
#  @param   {args}    args for the svn diff command
#  @return  <none>
svnDiff() {
    svnCommand diff $@
    return
}

## @fn      svnPropSet()
#  @brief   executes an svn propset command
#  @param   {args}    args for the svn propset command
#  @return  <none>
svnPropSet() {
    svnCommand propset $@
    return
}

## @fn      svnRemove()
#  @brief   executes an svn remove command
#  @param   {args}    args for the svn remove command
#  @return  <none>
svnRemove() {
    svnCommand rm $@
    return
}

## @fn      svnExport()
#  @brief   executes an svn export command
#  @param   {args}    args for the svn export command
#  @return  <none>
svnExport() {
    svnCommand export $@
    return
}

## @fn      svnLog()
#  @brief   executes an svn log command
#  @param   {args}    args for the svn propset command
#  @return  <none>
svnLog() {
    execute -n -r 3 svn log --non-interactive --trust-server-cert $@
    return
}

## @fn      svnCat()
#  @brief   executes an svn cat command
#  @param   {args}    args for the svn cat command
#  @return  output of the svn cat command
svnCat() {
    execute -n -r 3 svn cat --non-interactive --trust-server-cert $@
    return
}

## @fn      shouldNotExistsInSubversion()
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

## @fn      existsInSubversion()
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
    local tmp2=$(createTempFile)

    debug "checking in subversion for ${tag} in ${url}"
    execute -l ${tmp}  svn ls --xml ${url} 
    execute -l ${tmp2} ${LFS_CI_ROOT}/bin/xpath -q -e /lists/list/entry/name ${tmp}

    if grep -q "<name>${tag}</name>" ${tmp2} ; then
        return 0
    fi

    return 1
}

## @fn      mustExistInSubversion()
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

## @fn      mustExistBranchInSubversion()
#  @brief   ensures, that a branch exists in subversion
#  @details if the branch does not exists, the branch will be created (simple mkdir command)
#  @param   {url}           subversion url
#  @param   {branchName}    name of the branch
#  @return  <none>
mustExistBranchInSubversion() {
    local url=$1
    local branch=$2
    local logMessage=$(createTempFile)

    info "checking for branch ${url} / ${branch}"

    echo "creating a new branch: ${branch}" > ${logMessage}
    if ! existsInSubversion ${url} ${branch} ; then
        echo "BTSPS-1657 IN rh: DESRIPTION: NOJCHK : create dir ${url}/${branch}" > ${logMessage}
        svnMkdir -F ${logMessage} ${url}/${branch}
    fi

    return 0
}

## @fn      getSvnUrl()
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

## @fn      getSvnRevision()
#  @brief   get the revision for a svn url
#  @param   {url}    a svn url
#  @return  the svn revision
getSvnRevision() {
    local url=$1
    getSvnInfo ${url} "/info/entry/@revision" | cut -d'"' -f2
    return
}

## @fn      getSvnLastChangedRevision()
#  @brief   get the last changed revision for a svn url
#  @param   {url}    a svn url
#  @return  the last changed revision 
getSvnLastChangedRevision() {
    local url=$1
    getSvnInfo ${url} "/info/entry/commit/@revision" | cut -d'"' -f2
    return
}

## @fn      getSvnInfo()
#  @brief   get a specific information out of the svn info output for a svn url
#  @param   {url}      a svn url
#  @param   {xmlPath}  a xml path, e.g. /info/entry/commit/@revision for last changed revision   
#  @return  the information from svn info
getSvnInfo() {
    local url=$1
    local xmlPath=$2
    local tmpFile=$(createTempFile)

    execute -n svn info --xml ${url} > ${tmpFile}
    execute -n ${LFS_CI_ROOT}/bin/xpath -q -e ${xmlPath} ${tmpFile}

    return
}

## @fn      normalizeSvnUrl()
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
