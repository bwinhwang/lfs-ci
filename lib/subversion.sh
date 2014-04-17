#!/bin/bash

uploadToSubversion() {

    requiredParameters LFS_CI_ROOT

    local pathToUpload=$1
    local branchToUpload=$2
    local commitMessage="$3"

    info "upload local path ${pathToUpload} to ${branchToUpload}"

    # local tmp dir is to small
    local OLD_TMPDIR=${TMPDIR}
    export TMPDIR=/var/fpwork/${USER}/tmp/

    local branch=${locationToSubversionMap["${branchToUpload}"]}
    if [[ ! "${branch}" ]] ; then
        DEBUG "mapping for branchToUpload ${branchToUpload} not found"
        branch=${branchToUpload}
    fi

    execute ${LFS_CI_ROOT}/bin/svn_load_dirs.pl -m "${commitMessage}" \
                ${lfsDeliveryRepos} os/branches/${branch} \
                ${pathToUpload} \

    if [[ $? != 0 ]] ; then
        error "upload to svn failed"
        exit 1
    fi
    # reset to old / correct TMPDIR
    export TMPDIR=${OLD_TMPDIR}

    return
}

