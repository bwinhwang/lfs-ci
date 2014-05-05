#!/bin/bash

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

    execute ${LFS_CI_ROOT}/bin/svn_load_dirs.pl           \
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

svnCommand() {
    local args=$@
    debug "executing svn $@"
    execute svn --non-interactive --trust-server-cert $@
    return
}

svnCheckout() {
    svnCommand checkout $@
    return
}

svnCommit() {
    svnCommand commit $@
    return
}

svnDiff() {
    svnCommand diff $@
    return
}
