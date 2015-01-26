#!/bin/bash
## @file  jenkins.sh
#  @brief handling of the jenkins CLI

LFS_CI_SOURCE_jenkins='$Id$'

[[ -z ${LFS_CI_SOURCE_subversion} ]] && source ${LFS_CI_ROOT}/lib/subversion.sh
[[ -z ${LFS_CI_SOURCE_config}     ]] && source ${LFS_CI_ROOT}/lib/config.sh

## @fn      executeJenkinsCli()
#  @brief   execute a command via the jenkins CLI with some parameters
#  @details build                    Builds a job, and optionally waits until its completion.
#           cancel-quiet-down        Cancel the effect of the "quiet-down" command.
#           clear-queue              Clears the build queue
#           connect-node             Reconnect to a node
#           console                  Retrieves console output of a build
#           copy-job                 Copies a job.
#           create-job               Creates a new job by reading stdin as a configuration XML file.
#           create-node              Creates a new node by reading stdin as a XML configuration.
#           delete-builds            Deletes build record(s).
#           delete-job               Deletes a job
#           delete-node              Deletes a node
#           disable-job              Disables a job
#           disconnect-node          Disconnects from a node
#           enable-job               Enables a job
#           get-job                  Dumps the job definition XML to stdout
#           get-node                 Dumps the node definition XML to stdout
#           groovy                   Executes the specified Groovy script.
#           groovysh                 Runs an interactive groovy shell.
#           help                     Lists all the available commands.
#           install-plugin           Installs a plugin either from a file, an URL, or from update center.
#           install-tool             Performs automatic tool installation, and print its location to stdout. Can be only called from inside a build.
#           keep-build               Mark the build to keep the build forever.
#           list-changes             Dumps the changelog for the specified build(s).
#           list-jobs                Lists all jobs in a specific view or item group.
#           list-plugins             Outputs a list of installed plugins.
#           login                    Saves the current credential to allow future commands to run without explicit credential information.
#           logout                   Deletes the credential stored with the login command.
#           mail                     Reads stdin and sends that out as an e-mail.
#           offline-node             Stop using a node for performing builds temporarily, until the next "online-node" command.
#           online-node              Resume using a node for performing builds, to cancel out the earlier "offline-node" command.
#           quiet-down               Quiet down Jenkins, in preparation for a restart. Don?t start any builds.
#           reload-configuration     Discard all the loaded data in memory and reload everything from file system. Useful when you modified config files directly on disk.
#           restart                  Restart Jenkins
#           safe-restart             Safely restart Jenkins
#           safe-shutdown            Puts Jenkins into the quiet mode, wait for existing builds to be completed, and then shut down Jenkins.
#           session-id               Outputs the session ID, which changes every time Jenkins restarts
#           set-build-description    Sets the description of a build.
#           set-build-display-name   Sets the displayName of a build
#           set-build-parameter      Update/set the build parameter of the current build in progress
#           set-build-result         Sets the result of the current build. Works only if invoked from within a build.
#           shutdown                 Immediately shuts down Jenkins server
#           update-job               Updates the job definition XML from stdin. The opposite of the get-job command
#           update-node              Updates the node definition XML from stdin. The opposite of the get-node command
#           version                  Outputs the current version.
#           wait-node-offline        Wait for a node to become offline
#           wait-node-online         Wait for a node to become online
#           who-am-i                 Reports your credential and permissions
#  @param   {command}    a jenkins cli command
#  @param   {parameters} the parameters of the given command   
#  @return  <none>
executeJenkinsCli() {
    local java=$(getConfig java)
    local url=$(getConfig jenkinsMasterServerHttpUrl)
    local sshIdentity=$(getConfig jenkinsSshIdentification)
    local cli=$(getConfig jenkinsCli)

    execute ${java} -jar ${cli} -s "${url}" -i ${sshIdentity} $@
    return
}

## @fn      runJenkinsCli()
#  @brief   runs a jenkins cli command and returns the output to the caller
#  @param   {jenkins cli args}    list of arguments for the jenkins cli
#  @param   <none>
#  @return  output of jenkins cli
runJenkinsCli() {
    local tmpFile=$(createTempFile)
    local java=$(getConfig java)
    local url=$(getConfig jenkinsMasterServerHttpUrl)
    local sshIdentity=$(getConfig jenkinsSshIdentification)
    local cli=$(getConfig jenkinsCli)

    ${java} -jar ${cli} -s "${url}" -i ${sshIdentity} $@ 2> ${tmpFile}
    if [[ $? != 0 ]] ; then
        error "error in executing jenkins CLI: $@"
        rawDebug ${tmpFile}
        exit 1
    fi
    return
}

## @fn      setBuildDescription()
#  @brief   set the description of a build job
#  @param   {jobName}      name of the job
#  @param   {buildNumber}  number of the build
#  @param   {description}  description for the build (aka job/number)
#  @return  <none>
setBuildDescription() {
    local jobName=$1
    local buildNumber=$2
    local description="$3"

    # in some cases (development, ...) we want to avoid the error message 
    local canSetBuildDescription=$(getConfig JENKINS_can_set_build_description)
    [[ -z ${canSetBuildDescription} ]] && return

    echo ${description} | executeJenkinsCli set-build-description "${jobName}" "${buildNumber}" =

    return
}

## @fn      startBuildJobs()
#  @brief   start a jenkins job with a specified job name
#  @param   {jobName}    name of the job
#  @return  <none>
startBuildJobs() {
    local jobName=$1

    # TODO: demx2fk3 2014-05-12 not implemented yet

    return
}

## @fn      listJobNames()
#  @brief   list all jenkins jobs
#  @param   <none>
#  @return  list of jobs names
listJobNames() {
    local serverPath=$(getConfig jenkinsMasterServerPath)
    # TODO: demx2fk3 2014-09-16 fixme does not work in the correct way
    runOnMaster ls ${serverPath}/jobs
}

## @fn      getJob()
#  @brief   get the configuration of the jenkins project as xml.
#  @details the xml configuration will be written into the specified file
#  @param   {jobName}    name of the jenkins projekt
#  @param   {fileName}   output filename where the config should be written 
#  @return  <none>
getJob() {
    local jobName=$1
    local fileName=$2
    
    runJenkinsCli get-job "${jobName}" > ${fileName}

    return
}

## @fn      existsJenkinsJob()
#  @brief   checks, if the jenkins projekt / job exists or not
#  @param   {jobName}    name of the jenkins project
#  @return  <none>
#  @return  1 if jenkins projekt exists, 0 otherwise
existsJenkinsJob() {
    local jobName=$1

    if listJobNames | grep -q "^${jobName}$" ; then
        return 0
    fi

    return 1
}

## @fn      createJenkinsJob()
#  @brief   creates a jenkins job with the specified name and config
#  @param   {jobName}    name of the new jenkins project
#  @param   {fileName}   filename, which contains the config for the new jenkins project
#  @return  <none>
createJenkinsJob() {
    local jobName=$1
    local xmlConfigFile=$2

    executeJenkinsCli create-job "${jobName}" < ${xmlConfigFile}
    return
}

## @fn      updateJenkinsJob()
#  @brief   updates the configuration of a jenkins job with the given xml config file
#  @param   {jobName}    name of the jenkins project (aka job)
#  @param   {xmlConfigFile}    location of the xml config file
#  @return  <none>
updateJenkinsJob() {
    local jobName=$1
    local xmlConfigFile=$2

    mustHaveValue "${jobName}"       "job name"
    mustHaveValue "${xmlConfigFile}" "xml config file"
    mustExistFile "${xmlConfigFile}"

    executeJenkinsCli update-job "${jobName}" < ${xmlConfigFile}
    return
}

## @fn      deleteJenkinsJob()
#  @brief   delete a jenkins job with the specified name
#  @param   {jobName}     name of the jenkins project
#  @return  <none>
deleteJenkinsJob() {
    local jobName=$1

    executeJenkinsCli delete-job "${jobName}" 
    return
}

## @fn      disableJob()
#  @brief   disable the jenkins job
#  @param   {jobName}    name of the job
#  @return  <none>
disableJob() {
    local jobName=$1
    executeJenkinsCli disable-job "${jobName}"
    return
}

## @fn      enableJob()
#  @brief   enable the jenkins job
#  @param   {jobName}    name of the job
#  @return  <none>
enableJob() {
    local jobName=$1
    executeJenkinsCli enable-job "${jobName}"
    return
}

## @fn      setBuildResultUnstable()
#  @brief   set the build result of the currently running build to unstable
#  @param   <none>
setBuildResultUnstable() {
    executeJenkinsCli set-build-result unstable
    return
}

## @fn      setRevisionAsJobDescription()
#  @brief   set CI job description to SVN description
#  @param   {jobName}      name of the CI job
#  @param   {jobXmlFile}   name of the CI jobs XML file
#  @param   {branch}       name of the branch
setRevisionAsJobDescription() {
    requiredParameters LFS_CI_ROOT

    local jobXmlFile=$1
    mustHaveValue "${jobXmlFile}" "job xml file"

    local branch=$2
    mustHaveValue "${branch}" "branch name"

    local svnServer=$(getConfig lfsSourceRepos)
    local svnOutput=$(createTempFile)

    svnLog -v --xml --stop-on-copy $svnServer/os/$branch > $svnOutput
    [[ "$(grep '<msg>' $svnOutput)" ]] || fatal "invalid SVN xml output"

    local description=$(${LFS_CI_ROOT}/bin/xpath -q -e '/log/logentry/msg/node()' $svnOutput | tail -1 )
    local tmpFile=$(createTempFile)

    # 2014-12-01 eambrosc TODO try to use execute -n here
    ${LFS_CI_ROOT}/bin/xmlsubst.pl "project/description:=fix($description)" < $jobXmlFile > $tmpFile
    mustBeSuccessfull "$?" "xmlsubst.pl"

    execute cp -f $tmpFile $jobXmlFile

    return
}
