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
#  @param   {pathToUpload}       path names, which contains the files to upload to svn
#  @param   {svnUrl}             svn repos url - protokoll and servername / rootpath of the repos
#  @param   {svnBranchDirectory} svn path to upload without / at the beginning
#  @param   {svnTagDirectory}    svn path to create tag - including tag
#  @param   {message}            commit message
#  @return  <none>
uploadToSubversion() {
    local pathToUpload=$1
    mustHaveValue "${pathToUpload}" "location to upload to subversoin"
    local svnUrl=$2
    mustHaveValue "${svnUrl}" "svn url - pathout path"
    local svnBranchDirectory=$3
    mustHaveValue "${svnBranchDirectory}" "svn path to upload, without / at the end / beginning"
    local svnTagDirectory=$4
    local message="$5"

    local sleepTimeAfterCommit=$(getConfig LFS_PROD_uc_release_upload_to_subversion_sleep_time_after_commit)

    mustExistSubversionDirectory ${svnUrl} ${svnBranchDirectory}

    local oldTemp=${TMPDIR:-/tmp}
    _uploadToSubversionPrepareUpload
    _uploadToSubversionCopyToLocalDisk ${pathToUpload}
    _uploadToSubversionCheckoutWorkspace ${svnUrl}/${svnBranchDirectory}

    local svnUploadDirsOptions=""
    if [[ ${svnTagDirectory} ]] ; then
        svnUploadDirsOptions="${svnUploadDirsOptions} -t ${svnTagDirectory}"
        # we have to ensure, that the prefix path exists in svn: e.g. /os/tags/
        mustExistSubversionDirectory ${svnUrl} $(dirname ${svnTagDirectory})
    fi

    local workspace=${TMPDIR}/workspace
    if [[ -d ${workspace} ]] ; then
        svnUploadDirsOptions="${svnUploadDirsOptions} -wc ${workspace}"
    fi

    local svnCommitMessage=""
    if [[ "${message}" ]] ; then
        svnUploadDirsOptions="${svnUploadDirsOptions} -message '${message}'"
    fi

    info "upload to svn and create copy (${tagName})"
    execute -r 3 ${LFS_CI_ROOT}/lib/contrib/svn_load_dirs/svn_load_dirs.pl  \
                                         ${svnUploadDirsOptions}            \
                                         -v                                 \
                                         -no_user_input                     \
                                         -no_diff_tag                       \
                                         -glob_ignores="#.#"                \
                                         -sleep ${sleepTimeAfterCommit:-60} \
                                         ${svnUrl}                          \
                                         ${svnBranchDirectory}              \
                                         ${pathToUpload}       
    info "upload done";
    export TMPDIR=${oldTemp}

    return 0
}

## @fn      _uploadToSubversionPrepareUpload()
#  @brief   prepare the svn upload
#  @param   <none>
#  @return  <none>
_uploadToSubversionPrepareUpload() {
    local ramDisk=$(getConfig OS_ramdisk)
    mustExistDirectory "${ramDisk}" 

    debug "using ram disk ${ramDisk} for upload"

    export TMPDIR=${ramDisk}/${JOB_NAME}.${USER}/tmp

    debug "cleanup tmp directory"
    execute rm -rf ${TMPDIR}
    execute mkdir -p ${TMPDIR}

    # TMPDIR is not handled/created via createTempDirectory. So we have to
    # take care to clean up the temp directory after exit and failure
    exit_add _uploadToSubversionCleanupTempDirectory

    # ensure, that there are 15 GB disk space
    local freeDiskSpace=$(getConfig LFS_PROD_uc_release_upload_to_subversion_free_space_on_ramdisk)
    mustHaveFreeDiskSpace ${TMPDIR} ${freeDiskSpace} 

    return 0
}

## @fn      _uploadToSubversionCopyToLocalDisk()
#  @brief   copy the directory (to upload) to the local disk
#  @param   {pathToUpload}    path to upload to svn
#  @return  <none>
_uploadToSubversionCopyToLocalDisk() {
    local pathToUpload=$1
    mustExistDirectory ${pathToUpload}

    info "copy baseline to upload on local disk"
    local uploadDirectoryOnLocalDisk=${TMPDIR}/upload
    execute mkdir -p ${uploadDirectoryOnLocalDisk}
    execute rsync --delete -av ${pathToUpload}/ ${uploadDirectoryOnLocalDisk}/

    return 0
}

## @fn      _uploadToSubversionCheckoutWorkspace()
#  @brief   (pre)checkout the svn repos to the workspace, which svn upload will use
#  @param   {svnUrl}    svn url with path 
#  @return  <none>
_uploadToSubversionCheckoutWorkspace() {
    local svnUrl=$1

    local workspace=${TMPDIR}/workspace
    info "checkout svn workspace for upload preparation"
    execute rm -rf ${workspace}
    execute mkdir -p ${workspace}
    svnCheckout ${svnUrl} ${workspace}

    return 0
}

## @fn      _uploadToSubversionCleanupTempDirectory()
#  @brief   cleanup the created temp directory in svn upload function
#  @param   <none>
#  @return  <none>
_uploadToSubversionCleanupTempDirectory() {
    requiredParameters JOB_NAME USER

    local ramDisk=$(getConfig OS_ramdisk)
    mustExistDirectory "${ramDisk}" 

    local tmpDirectory=${ramDisk}/${JOB_NAME}.${USER}
    [[ -d ${tmpDirectory} ]] && rm -rf ${tmpDirectory}

    return
}


## @fn      mustExistSubversionDirectory()
#  @brief   ensure, that the directory in subversion exists
#  @param   {prefixPath}    svn server url
#  @param   {pathName}      path name
#  @return  <none>
mustExistSubversionDirectory() {
    local prefixPath=${1}
    mustHaveValue "${prefixPath}" "prefix path"
    local localPath=${2} 
    mustHaveValue "${localPath}" "local path"

    debug "check for sub dir ${prefixPath} ${localPath}"
    
    local newLocalPath=$(cut -d/ -f1 <<< ${localPath})
    local newRestPath=$(cut -d/ -f2- <<< ${localPath})
    
    if [[ ${newRestPath} == ${localPath} ]] ; then
        # end of recursion condition
        debug "end of recursion"
        mustExistBranchInSubversion ${prefixPath} ${newLocalPath}
        return
    elif [[ -z ${newLocalPath} ]] ; then
        # someone started or ended the localPath with a /
        # so we skip the element
        debug "skipping -z ${newLocalPath}"
        mustExistSubversionDirectory ${prefixPath}/${newLocalPath} ${newRestPath}
    else 
        debug "creating svn dir ${prefixPath} ${newRestPath}"
        mustExistBranchInSubversion ${prefixPath} ${newLocalPath}
        mustExistSubversionDirectory ${prefixPath}/${newLocalPath} ${newRestPath}
    fi  
    
    return
}

## @fn      svnCommand()
#  @brief   execute the given subversion command with the specified parameters
#  @param   {args}    command and arguments of the svn command
#  @return  <none>
svnCommand() {
    debug "executing svn $@"
    local svnArguments=$(getConfig SVN_cli_args -t command:$1)
    execute -r 3 svn ${svnArguments} $@
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

## @fn      svnStatus()
#  @brief   executes an svn status command
#  @param   {args}    args for the svn status command
#  @return  <none>
svnStatus() {
    svnCommand status $@
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
    local svnArguments=$(getConfig SVN_cli_args -t command:log)
    execute -n -r 3 svn log ${svnArguments} $@
    return
}

## @fn      svnCat()
#  @brief   executes an svn cat command
#  @param   {args}    args for the svn cat command
#  @return  output of the svn cat command
svnCat() {
    local svnArguments=$(getConfig SVN_cli_args -t command:log)
    execute -n -r 3 svn cat ${svnArguments} $@
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
    local svnArguments=$(getConfig SVN_cli_args -t command:ls)

    debug "checking in subversion for ${tag} in ${url}"
    execute -l ${tmp}  svn ls ${svnArguments} --xml ${url} 
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

    # TODO: demx2fk3 2015-08-04 enable this code
    # local svnCommitMessagePrefix=$(getConfig LFS_PROD_uc_release_svn_message_prefix)
    # mustHaveValue "${svnCommitMessagePrefix}" "svn commit message"

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

    local svnArguments=$(getConfig SVN_cli_args -t command:info)
    execute -n svn info ${svnArguments} --xml ${url} > ${tmpFile}
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
