#!/bin/bash

## @fn      actionCompare()
#  @brief   this command is called by jenkins custom scm plugin via a
#           polling trigger. It should decide, if a build is required
#           or not
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
# 
#           TODO: demx2fk3 2014-11-03 fix the documentation, It seems outdated
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
    mustExistFile ${oldRevisionsFile}
    debug "old revision state file data"
    rawDebug ${oldRevisionsFile}

    local newRevisionsFile=$(createTempFile)
    execute rm -rf ${WORKSPACE}/revision_state.txt
    _createRevisionsTxtFile ${newRevisionsFile}
    execute cp ${newRevisionsFile} ${WORKSPACE}/revision_state.txt

    debug "old revision state file"
    rawDebug ${oldRevisionsFile}
    debug "new revision state file"
    rawDebug ${newRevisionsFile}

    # execute diff -rub ${oldRevisionsFile} ${newRevisionsFile}

    local isMaintenance=$(getConfig CUSTOM_SCM_svn_trigger_svn_is_maintenance)

    if [[ ${isMaintenance} ]] ; then
        warning "maintenance is active, no build"
        exit 1
    fi

    # now we have both files, we can compare them
    if cmp --silent ${oldRevisionsFile} ${newRevisionsFile} ; then
        info "no changes in revision files, no build required"
        exit 1
    else

        local tmpFile=$(createTempFile)
        diff -rub ${oldRevisionsFile} ${newRevisionsFile} > ${tmpFile}
        rawDebug ${tmpFile}

        local changelogFile=$(createTempFile)
        _createChangelogXmlFileFromSubversion ${oldRevisionsFile} ${newRevisionsFile} ${changelogFile}
        
        local commentsFile=$(createTempFile)
        local commentsFileFiltered=$(createTempFile)
        execute -n xpath -q -e '/log/logentry/msg/node()' ${changelogFile} > ${commentsFile}
        grep -s -v -e "BTS-1657" \
                   -e "^$" \
                   ${commentsFile} > ${commentsFileFiltered}

        debug "comment file data"
        rawDebug ${commentsFile}

        debug "comment file data filtered"
        rawDebug ${commentsFileFiltered}

        local commentsCount=$(wc -l ${commentsFile} | cut -d" " -f 1)
        local commentsCountFiltered=$(wc -l ${commentsFileFiltered} | cut -d" " -f 1)

        info "comment lines: ${commentsCountFiltered} of ${commentsCount}"

        if [[ ${commentsCountFiltered} -eq 0 ]] ; then
            info "changed detected, but filtered out commit found. No commit left."
            exit 1
        fi

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
    #FIXME don't use the ENV variables, make a copy
    if [[ ! -e ${OLD_REVISION_STATE_FILE} ]] ; then
        warning "error OLD_REVISION_STATE_FILE does not exist, create a temp file"
        OLD_REVISION_STATE_FILE=$(createTempFile)
        execute touch ${OLD_REVISION_STATE_FILE}
    fi

    _createChangelogXmlFileFromSubversion \
            ${OLD_REVISION_STATE_FILE}    \
            ${REVISION_STATE_FILE}        \
            ${CHANGELOG}

    debug "revision state file"
    rawDebug ${REVISION_STATE_FILE}

    exit 0
}

## @fn      actionCalculate()
#  @brief   no nothing at the moment
#  @param   <none>
#  @return  <none>
actionCalculate() {
    return 
}

## @fn      _createRevisionsTxtFile( $fileName )
#  @brief   create the revisions.txt file 
#  @details see actionCompare for more details
#  @param   {fileName}    file name
#  @return  <none>
_createRevisionsTxtFile() {

    local newRevisionsFile=$1
    dependenciesFile=$(createTempFile)
    
    locationName=$(getLocationName)
    mustHaveLocationName

    if [[ -f ${WORKSPACE}/revision_state.txt ]] ; then
        info "using ${WORKSPACE}/revision_state.txt from compare"
        # cat ${WORKSPACE}/revision_state.txt > ${newRevisionsFile}
        # return
    fi

    local srcRepos=$(getConfig lfsSourceRepos)

    execute touch ${newRevisionsFile}

    # get the locations/<branch>/Dependencies
    local branch=

    # TODO: demx2fk3 2014-11-04 this feature does not work
    # for branch in ${locationName} $(getConfig CUSTOM_SCM_svn_additional_location)

    for branch in ${locationName} 
    do
        local dependenciesFileUrl=${srcRepos}/os/trunk/bldtools/locations-${branch}/Dependencies
        # check, if dependency file exists
        execute svn ls ${dependenciesFileUrl} 

        # can not use execute here, so we have to do the error handling by hande
        # do the magic for all dir
        info "dependenciesFileUrl is ${dependenciesFileUrl}"

        local tmpFile1=$(createTempFile)
        execute -n ${LFS_CI_ROOT}/bin/getRevisionTxtFromDependencies \
                    -u ${dependenciesFileUrl}                        \
                    -f ${dependenciesFile}                           \
                    > ${tmpFile1}
        execute -n sort -u ${tmpFile1} > ${newRevisionsFile} 

        debug "got revisions from ${dependenciesFileUrl}"
        rawDebug ${newRevisionsFile}

    done

    # add also buildtools location
    local bldToolsUrl=${srcRepos}/os/trunk/bldtools/bld-buildtools-common
    local rev=$(svn info --xml ${bldToolsUrl}| ${LFS_CI_ROOT}/bin/xpath -q -e '/info/entry/commit/@revision'  | cut -d'"' -f 2)
    mustHaveValue "${rev}" "svn info ${bldToolsUrl} didnt get a value for revision"

    printf "%s %s %s" bld-buildtools "${bldToolsUrl}" "${rev}" >> ${newRevisionsFile}

    local filterFile=$(getConfig CUSTOM_SCM_svn_filter_components_file)
    if [[ -e ${filterFile} ]] ; then
        info "using custom SCM filter ${filterFile}"
        local tmpFile=$(createTempFile)
        grep -w -f ${filterFile} ${newRevisionsFile} > ${tmpFile}
        execute mv -f ${tmpFile} ${newRevisionsFile}

        rawDebug ${newRevisionsFile}
    fi

    return
}

## @fn      _createChangelogXmlFileFromSubversion( $oldRevisionStateFile, $revisionStateFile, $changelogFile )
#  @brief   create the changelog.xml file from subversion 
#  @details the method creates the changelog.xml out from subversion based on the differences
#           in the old revision state file and the revision state file.
#  @param   {oldRevisionStateFile}    old revision state file
#  @param   {revisionStateFile}       revision state file
#  @param   {changelogFile}           changelog xml file
#  @return  <none>
_createChangelogXmlFileFromSubversion() {
    local oldRevisionsFile=${1:-${OLD_REVISION_STATE_FILE}}
    debug "old revision file"
    rawDebug ${oldRevisionsFile}

    debug "generate the new revision file"
    local newRevisionsFile=${2:-${REVISION_STATE_FILE}}
    _createRevisionsTxtFile ${newRevisionsFile}
    debug "new revision state file"
    rawDebug ${newRevisionsFile}

    local changelogFile=${3:-${CHANGELOG}}
    cat < /dev/null > "${changelogFile}"
    mustExistFile ${changelogFile}

    # check the revision from old state file and current state file
    for subSystem in $(cut -d" " -f 1 ${newRevisionsFile}) ; do

        oldUrl=$(grep -e "^${subSystem} " ${oldRevisionsFile} | cut -d" " -f2)
        oldRev=$(grep -e "^${subSystem} " ${oldRevisionsFile} | cut -d" " -f3)

        newUrl=$(grep -e "^${subSystem} " ${newRevisionsFile} | cut -d" " -f2)
        newRev=$(grep -e "^${subSystem} " ${newRevisionsFile} | cut -d" " -f3)

        debug "old revision data: ${oldUrl} ${oldRev}"
        debug "new revision data: ${newUrl} ${newRev}"

        if [[ "${oldUrl}" != "${newUrl}" ]] ; then
            # just get the latest revision
            continue
        fi
        if [[ "${oldRev}" != "${newRev}" ]] ; then
            # get the changes
            local tmpChangeLogFile=$(createTempFile)

            oldRev=$(( oldRev + 1))
            debug "get svn changelog ${subSystem} ${oldRev}:${newRev} ${newUrl}"
            execute -n svn log -v --xml -r${oldRev}:${newRev} ${newUrl} > ${tmpChangeLogFile}
            mustBeSuccessfull "$?" "svn log -v --xml -r${oldRev}:${newRev} ${newUrl}"

            rawDebug ${tmpChangeLogFile}

            # check for an empty file 
            if [[ $(wc -l ${tmpChangeLogFile} | cut -d" " -f1 ) -eq 3 ]] ; then
                trace "empty xml file, skipping"
                continue
            fi

            if [[ ! -s ${changelogFile} ]] ; then
                debug "copy ${tmpChangeLogFile} to ${changelogFile}"
                execute cp -f ${tmpChangeLogFile} ${changelogFile}
            else
                debug "using xsltproc to create new ${changelogFile}"
                execute xsltproc                                          \
                            --stringparam file ${tmpChangeLogFile}        \
                            --output ${changelogFile}                     \
                            ${LFS_CI_ROOT}/lib/contrib/joinChangelog.xslt \
                            ${changelogFile}  
            fi
        fi
    done

    # Remove inter-log cruft arising from the concatenation of individual
    # changelogs:
    sed -i 's:</log><?xml[^>]*><log>::g' "${changelogFile}"

    # Fix empty changelogs:
    if [ ! -s "${changelogFile}" ] ; then
        echo -n "<log/>" >"${changelogFile}"
    fi

    rawDebug ${changelogFile}

    return
}

