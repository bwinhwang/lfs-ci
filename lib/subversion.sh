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
