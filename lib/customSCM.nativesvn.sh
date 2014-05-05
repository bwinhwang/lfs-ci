#!/bin/bash

export SVN_URL=file:///home/demx2fk3/svn/foobar/

## @fn      actionCompare()
#  @brief   this command is called by jenkins custom scm plugin via a
#           polling trigger. It should decide, if a build is required
#           or not
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
#  @param   <none>
#  @return  1 if if a build is not required, 0 otherwise
actionCompare() {

    if [[ -z "${REVISION_STATE_FILE}" ]] ; then
        info "no old revision state file found"
        exit 0
    fi

    # generate the new revsions file
    local oldRevisionsFile=${REVISION_STATE_FILE}

    local newRevisionsFile=$(createTempFile)
    svn info --xml $SVN_URL | ${LFS_CI_ROOT}/bin/xpath -q -e '//info/entry/commit/@revision' | cut -d'"' -f 2 >  ${newRevisionsFile}

    # now we have both files, we can compare them
    if cmp --silent ${oldRevisionsFile} ${newRevisionsFile} ; then
        info "no changes in revision files, no build required"
        exit 1
    else
        info "changes in revision file found, trigger build"
        exit 0
    fi

    return
}


## @fn      actionCheckout()
#  @brief   action which is called by custom scm jenkins plugin to create or update a workspace and create the changelog
#  @details the create workspace task is empty here. We just calculate the changelog
#  @param   <none>
#  @return  <none>
actionCheckout() {
    # changelog handling
    # idea: the upstream project has the correct change log. We have to get it from them.
    # For this, we get the old revision state file and the revision state file.
    # This includes the upstream project name and the upstream build number.
    # So the job is easy: get the changelog of the upstream project builds between old and new
    #
    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"

    svn info --xml $SVN_URL | $LFS_CI_ROOT}/bin/xpath -q -e '//info/entry/commit/@revision' | cut -d'"' -f 2 >  ${REVISION_STATE_FILE}
    local oldRevisions=$(cat ${OLD_REVISION_STATE_FILE})
    local newRevisions=$(cat ${REVISION_STATE_FILE})
    oldRevisions=$(( oldRevisions + 1 ))

    svn log -v --xml -r${oldRevisions}:${newRevisions} ${SVN_URL} > ${CHANGELOG}

    # Fix empty changelogs:
    if [ ! -s "$CHANGELOG" ] ; then
        echo -n "<log/>" >"$CHANGELOG"
    fi
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details «full description»
#  @param   <none>
#  @return  <none>
actionCalculate() {

    return 
}

return
