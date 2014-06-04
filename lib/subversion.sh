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

    local svnReposUrl=$(getConfig lfsOsDeliveryRepos)

    info "upload local path ${pathToUpload} to ${branchToUpload}"

    local branch=${locationToSubversionMap["${branchToUpload}"]}
    if [[ ! "${branch}" ]] ; then
        DEBUG "mapping for branchToUpload ${branchToUpload} not found"
        branch=${branchToUpload}
    fi
    local oldTemp=${TMPDIR}
    export TMPDIR=${WORKSPACE}/tmp/
    debug "cleanup tmp directory"
    rm -rf ${TMPDIR}
    mkdir -p ${TMPDIR}

    mustHaveNextLabelName
    local tagName=$(getNextReleaseLabel)

    local branchPath=$(getConfig SVN_branch_path_name)
    local tagPath=$(getConfig SVN_tag_path_name)
    mustHaveValue "${tagPath}"
    mustHaveValue "${branchPath}"

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

svnMkdir() {
    svnCommand mkdir $@
    return
}

svnCopy() {
    svnCommand copy $@
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

svnPropSet() {
    svnCommand propset $@
    return
}

svnRemove() {
    svnCommand rm $@
    return
}

svnExistsPath() {
    return
}

shouldNotExistsInSubversion() {
    local url=$1
    local tag=$2

    if existsInSubversion ${url} ${tag} ; then
        error "entry ${tag} exists in ${url}"
        exit 1
    fi
    return 0
}

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

mustExistInSubversion() {
    local url=$1
    local tag=$2

    if ! existsInSubversion ${url} ${tag} ; then
        error "entry ${tag} exists in ${url}"
        exit 1
    fi

    return 0
}

getSvnUrl() {
    local url=$1
    getSvnInfo ${url} '/info/entry/url/node()'
    return
}

getSvnRevision() {
    local url=$1
    getSvnInfo ${url} "/info/entry/@revision" | cut -d'"' -f2
    return
}

getSvnLastChangedRevision() {
    local url=$1
    getSvnInfo ${url} "/info/entry/commit/@revision" | cut -d'"' -f2
    return
}

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
