#!/bin/bash

## @fn      actionCompare()
#  @brief   this command is called by jenkins custom scm plugin via a
#           polling trigger. It should decide, if a build is required
#           or not
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
# 
#           Idea: we get the information from the old build in the
#           BUILD_URL_LAST (old project name and old build
#           number). With this information we can look for the
#           revisions.txt file, which is located on the jenkins
#           master server in the build directory of the old build
#           ($JENKINS_HOME/jobs/<projekt>/builds/<number>). In the next
#           step, we have to create the same revisions.txt for the head
#           revisions of the used svn repos (we need the svn urls with
#           branches, ...) which are used in the trunk / branch. This
#           info is located in the locations/<branch>/Dependencies
#           files. So the steps got the the new revisions.txt are:
# 
#           * get the branch / trunk information (use the job name)
# 
#           * get the locations/<branch>/Dependencies file from svn
#           (svn cat <url>)
# 
#           * generate all urls from "build listdirs" (aka
#           grep -h '^'"dir " locations/*/Dependencies) and
#           locations/<branch>/Dependencies with revisions
# 
#           * if the new generated and the old, stored files are
#           different, trigger a new build, and store the new file
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
    _createRevisionsTxtFile ${newRevisionsFile}

    # now we have both files, we can compare them
    if cmp --silent ${oldRevisionsFile} ${newRevisionsFile} ; then
        info "no changes in revision files, no build required"
        exit 1
    else
        info "changes in revision file found, trigger build"
        tmpFile=$(createTempFile)
        diff -rub ${oldRevisionsFile} ${newRevisionsFile} > ${tmpFile}
        rawDebug ${tmpFile}
        exit 0
    fi

    return
}

## @fn      _createRevisionsTxtFile( $fileName )
#  @brief   create the revisions.txt file 
#  @details see actionCompare for more details
#  @param   {fileName}    file name
#  @param   <none>
#  @return  <none>
_createRevisionsTxtFile() {

    local newRevisionsFile=$1
    dependenciesFile=$(createTempFile)
    
    locationName=$(getLocationName)
    mustHaveLocationName

    info "get the locations/<branch>/Dependencies"
    dependenciesFileUrl=${lfsSourceRepos}/os/trunk/bldtools/locations-${locationName}/Dependencies
    if ! svn ls ${dependenciesFileUrl} >/dev/null 
    then
        error "svn is not responding or ${dependenciesFileUrl} does not exist"
        exit 1
    fi

    # can not use execute here, so we have to do the error handling by hande
    # do the magic for all dir
    info "create revisions.txt via perl"
    ${LFS_CI_ROOT}/bin/getRevisionTxtFromDependencies -u ${dependenciesFileUrl} \
                                                      -f ${dependenciesFile} > ${newRevisionsFile} 
    if [[ $? != 0 ]] ; then
        error "reported an error..."
        exit 1
    fi

    info "add also buildtools location"
    set -x
    local bldToolsUrl=${lfsSourceRepos}/os/trunk/bldtools/bld-buildtools-common
    echo "svn info --xml ${bldToolsUrl}| ${LFS_CI_ROOT}/bin/xpath -q -e '/info/entry/commit/@revision' "
    local rev=$(svn info --xml ${bldToolsUrl}| ${LFS_CI_ROOT}/bin/xpath -q -e '/info/entry/commit/@revision'  | cut -d'"' -f 2)
    printf "%s %s %s" bld-buildtools "${bldToolsUrl}" "${rev}" >> ${newRevisionsFile}
    set +x

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

    local oldRevisionsFile=${OLD_REVISION_STATE_FILE}

    debug "generate the new revision file"
    local newRevisionsFile=${REVISION_STATE_FILE}
    _createRevisionsTxtFile ${newRevisionsFile}

    # check the revision from old state file and current state file
    for subSystem in $(cut -d" " -f 1 ${newRevisionsFile}) ; do

        oldUrl=$(grep -e "^${subSystem} " ${oldRevisionsFile} | cut -d" " -f2)
        oldRev=$(grep -e "^${subSystem} " ${oldRevisionsFile} | cut -d" " -f3)

        newUrl=$(grep -e "^${subSystem} " ${newRevisionsFile} | cut -d" " -f2)
        newRev=$(grep -e "^${subSystem} " ${newRevisionsFile} | cut -d" " -f3)

        if [[ "${oldUrl}" != "${newUrl}" ]] ; then
            # just get the latest revision
            continue
        fi
        if [[ "${oldRev}" != "${newRev}" ]] ; then
            # get the changes
            info "get changelog for ${subSystem}"
            local tmpChangeLogFile=$(createTempFile)
            svn log -v --xml -r${oldRev}:${newRev} ${newUrl} > ${tmpChangeLogFile}
            if [[ $? != 0 ]] ; then
                error "svn log -v --xml -r${oldRev}:${newRev} ${newUrl} failed"
                exit 1
            fi

            cat ${tmpChangeLogFile}

            if [[ ! -s ${CHANGELOG} ]] ; then
                debug "copy ${tmpChangeLogFile} to ${CHANGELOG}"
                execute cp -f ${tmpChangeLogFile} ${CHANGELOG}
            else
                debug "using xsltproc to create new ${CHANGELOG}"
                local tmpChangeLogFile=$(createTempFile)
                execute xsltproc                                          \
                            --stringparam file ${tmpChangeLogFile}        \
                            --output ${CHANGELOG}                         \
                            ${LFS_CI_ROOT}/lib/contrib/joinChangelog.xslt \
                            ${CHANGELOG}  
            fi
            cat ${CHANGELOG}
        fi
    done

    # Remove inter-log cruft arising from the concatenation of individual
    # changelogs:
    sed -i 's:</log><?xml[^>]*><log>::g' "$CHANGELOG"

    # Fix empty changelogs:
    if [ ! -s "$CHANGELOG" ] ; then
        echo -n "<log/>" >"$CHANGELOG"
    fi

    exit 0
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
