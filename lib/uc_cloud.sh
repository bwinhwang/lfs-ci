#!/bin/bash
## @file    uc_cloud.sh
#  @brief   usecase cloud
#  @details the start cloud instance usecase for lfs.

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

## @fn      usecase_ADMIN_CREATE_CLOUD_SLAVE_INSTANCE()
#  @brief   usecase to create a new LFS CI eecloud slave (https://psweb.nsn-net.net/PS/Wiki/doku.php?id=lfs:production:ci_version2:howto_setup_new_cloud_server)
#  @param   <none>
#  @return  <none>
usecase_ADMIN_CREATE_CLOUD_SLAVE_INSTANCE() {
    requiredParameters CREATE_CLOUD_INSTANCES_AMOUNT CREATE_CLOUD_INSTANCES_TYPE JOB_NAME BUILD_NUMBER

    info *****************************************************************************************************
    info * CREATE_CLOUD_INSTANCES_AMOUNT       = ${CREATE_CLOUD_INSTANCES_AMOUNT}
    info * CREATE_CLOUD_INSTANCES_TYPE         = ${CREATE_CLOUD_INSTANCES_TYPE}
    info * CREATE_CLOUD_INSTANCES_NEW_CI_SLAVE = ${CREATE_CLOUD_INSTANCES_NEW_CI_SLAVE}
    info *****************************************************************************************************

    local cloudLfs2Cloud=$(getConfig LFS_CI_CLOUD_LFS2CLOUD)
    mustHaveValue "${cloudLfs2Cloud}" "cloudLfs2Cloud"
    local cloudUserRootDir=$(getConfig LFS_CI_CLOUD_USER_ROOT_DIR)
    mustHaveValue "${cloudUserRootDir}" "cloudUserRootDir"
    local cloudEsloc=$(getConfig LFS_CI_CLOUD_SLAVE_ESLOC)
    mustHaveValue "${cloudEsloc}" "cloudEsloc"
    local cloudEucarc=$(getConfig LFS_CI_CLOUD_SLAVE_EUCARC)
    mustHaveValue "${cloudEucarc}" "cloudEucarc"
    local cloudEmi=$(getConfig LFS_CI_CLOUD_SLAVE_EMI)
    mustHaveValue "${cloudEmi}" "cloudEmi"
    local cloudInstanceType=${CREATE_CLOUD_INSTANCES_TYPE}
    mustHaveValue "${cloudInstanceType}" "cloudInstanceType"
    local cloudInstanceStartParams=$(getConfig LFS_CI_CLOUD_SLAVE_INST_START_PARAMS)
    mustHaveValue "${cloudInstanceStartParams}" "cloudInstanceStartParams"
    local cloudInstallScript=$(getConfig LFS_CI_CLOUD_SLAVE_INSTALL_SCRIPT)
    mustHaveValue "${cloudInstallScript}" "cloudInstallScript"

    # source seesetenv euca2ools=3.1.1. is already done via entry in linsee.cfg
    info Sourcing eucarc with: source ${cloudUserRootDir}/${cloudEucarc}
    #mustExistFile ${cloudUserRootDir}/${cloudEucarc}
    source ${cloudUserRootDir}/${cloudEucarc}

    local allcloudDnsName=""
    export INST_START_PARAMS="${cloudInstanceStartParams}"
    export HVM=1

    for counter in `seq ${CREATE_CLOUD_INSTANCES_AMOUNT}`
    do
        info Starting cloud instance ${counter} with: execute export INST_START_PARAMS="${INST_START_PARAMS}" ';' export HVM=${HVM} ';' ${cloudLfs2Cloud} -c${cloudEsloc} -i${cloudEmi} -m${cloudInstanceType} -sLFS_CI -f${cloudInstallScript}
        local cloudStartLog=$(createTempFile)
        if ! $(execute -l ${cloudStartLog} ${cloudLfs2Cloud} -c${cloudEsloc} -i${cloudEmi} -m${cloudInstanceType} -sLFS_CI -f${cloudInstallScript})
        then
            if [[ $counter -gt 1 ]] 
            then
                info Already started cloud instances: ${allcloudDnsName}
                error Error during starting a new cloud instance
                setBuildResultUnstable
            else
                fatal Could not create a cloud instance
            fi
        fi

        local searchForDNSString='successfully started )'
        local cloudDnsName=$(grep "${searchForDNSString}" ${cloudStartLog} | cut -d\( -f2 | sed "s/${searchForDNSString}//" | sed "s/ //g")
        debug cloudDnsName=${cloudDnsName}
        mustHaveValue "${cloudDnsName}" "cloudDnsName"
        local searchForInstanceIDString='Awaiting Instance'
        local instanceID=$(grep "${searchForInstanceIDString}" ${cloudStartLog} | sed "s/${searchForInstanceIDString}//" | cut -d\[ -f2 | cut -d\] -f1)
        debug instanceID=${instanceID}
        mustHaveValue "${instanceID}" "instanceID"

        info Started cloud instance ${cloudDnsName} [${instanceID}]

        # only a cosmetic that BuildDescription doesn't start wit a LF
        if [[ ${counter} == 1 ]]
        then
            allcloudDnsName="${cloudDnsName} [${instanceID}]"
        else
            allcloudDnsName="${allcloudDnsName} <br>${cloudDnsName} [${instanceID}]"
        fi
        debug allcloudDnsName=${allcloudDnsName}

        [[ ${CREATE_CLOUD_INSTANCES_NEW_CI_SLAVE} ]] && addNewCloudInstanceToJenkins ${cloudDnsName} ${instanceID}
    done

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${allcloudDnsName}"

    return 0
}

## @fn      addNewCloudInstanceToJenkins
#  @brief   added new cloud instance as node for jenkins
#  @param   <none>
#  @return  <none>
addNewCloudInstanceToJenkins() {
    info New cloud instance will be added to Jenkins ...
    local cloudDnsName=$1
    mustHaveValue "${cloudDnsName}" "cloudDnsName"
    local instanceID=$2
    mustHaveValue "${instanceID}" "instanceID"

    local newCloudNodeConfigXml=$(createTempFile)
    createNewCloudNodeXMLConfig ${newCloudNodeConfigXml} ${cloudDnsName} ${instanceID}
    createNewJenkinsNode ${newCloudNodeConfigXml}

    local newCloudNodeCleanupJobConfigXml=$(createTempFile)
    createNewCloudNodeAdminCleanupXMLConfig ${newCloudNodeCleanupJobConfigXml} ${instanceID}
    createNewJenkinsNodeAdminCleanupJob ${newCloudNodeCleanupJobConfigXml} ${instanceID}
}

## @fn      createNewCloudNodeXMLConfig
#  @brief   create a new config.xml for this new cloud node
#  @param   <none>
#  @return  <none>
createNewCloudNodeXMLConfig() {
    local newCloudNodeConfigXml=$1
    mustHaveValue "${newCloudNodeConfigXml}" "newCloudNodeConfigXml"
    local cloudDnsName=$2
    mustHaveValue "${cloudDnsName}" "cloudDnsName"
    local instanceID=$3
    mustHaveValue "${instanceID}" "instanceID"
    local jenkinsRoot=$(getConfig jenkinsRoot)
    mustHaveValue "${jenkinsRoot}" "jenkinsRoot"

    cat >${newCloudNodeConfigXml} <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<slave>
EOF
    echo " <name>${instanceID}</name>" >> ${newCloudNodeConfigXml}
    echo " <description>${cloudDnsName}</description>" >> ${newCloudNodeConfigXml}
    echo " <remoteFS>${jenkinsRoot}</remoteFS>" >> ${newCloudNodeConfigXml}
    cat >>${newCloudNodeConfigXml} <<EOF
 <numExecutors>2</numExecutors>
 <mode>NORMAL</mode>
 <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
 <launcher class="hudson.plugins.sshslaves.SSHLauncher" plugin="ssh-slaves@1.6">
EOF
    echo "  <host>${cloudDnsName}</host>" >> ${newCloudNodeConfigXml}
    cat >>${newCloudNodeConfigXml} <<EOF
  <port>22</port>
  <credentialsId>ee8254a1-555d-465a-b43f-eb0856b0672c</credentialsId>
 </launcher>
 <label>cloud espoo knife testDummyHost</label>
 <nodeProperties>
  <hudson.slaves.EnvironmentVariablesNodeProperty>
   <envVars serialization="custom">
    <unserializable-parents/>
    <tree-map>
     <default>
     <comparator class="hudson.util.CaseInsensitiveComparator"/>
     </default>
     <int>2</int>
     <string>LFS_CI_ROOT</string>
     <string>/ps/lfs/ci</string>
     <string>LFS_CI_SHARE_MIRROR</string>
    <string>/var/fpwork</string>
    </tree-map>
   </envVars>
  </hudson.slaves.EnvironmentVariablesNodeProperty>
 </nodeProperties>
 <userId>anonymous</userId>
</slave>
EOF

    info config.xml for cloud node ${cloudDnsName} [${instanceID}] written.
    rawDebug ${newCloudNodeConfigXml}
}

## @fn      createNewJenkinsNode
#  @brief   create a new node for jenkins
#  @param   <none>
#  @return  <none>
createNewJenkinsNode() {
    local newCloudNodeConfigXml=$1
    mustExistFile ${newCloudNodeConfigXml}
    local jenkinsCli=$(getConfig jenkinsCli)
    #mustExistFile ${jenkinsCli}

    info +++ TODO java -jar ${jenkinsCli}  -s http://maxi:1280  create-node < ${newCloudNodeConfigXml}
}

## @fn      createNewCloudNodeAdminCleanupXMLConfig
#  @brief   create a new config.xml for a new admin cleanup job of that node
#  @param   <none>
#  @return  <none>
createNewCloudNodeAdminCleanupXMLConfig() {
    local newCloudNodeCleanupJobConfigXml=$1
    mustHaveValue "${newCloudNodeCleanupJobConfigXml}" "newCloudNodeCleanupJobConfigXml"
    local instanceID=$2
    mustHaveValue "${instanceID}" "instanceID"

   cat >${newCloudNodeCleanupJobConfigXml} <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project>
 <actions/>
 <description/>
 <logRotator class="hudson.tasks.LogRotator">
  <daysToKeep>10</daysToKeep>
  <numToKeep>-1</numToKeep>
  <artifactDaysToKeep>-1</artifactDaysToKeep>
  <artifactNumToKeep>-1</artifactNumToKeep>
 </logRotator>
 <keepDependencies>false</keepDependencies>
 <properties>
  <com.sonyericsson.jenkins.plugins.bfa.model.ScannerJobProperty plugin="build-failure-analyzer@1.12.1">
   <doNotScan>false</doNotScan>
  </com.sonyericsson.jenkins.plugins.bfa.model.ScannerJobProperty>
  <jenkins.advancedqueue.AdvancedQueueSorterJobProperty plugin="PrioritySorter@2.8">
   <useJobPriority>false</useJobPriority>
   <priority>-1</priority>
  </jenkins.advancedqueue.AdvancedQueueSorterJobProperty>
  <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.22">
   <autoRebuild>false</autoRebuild>
  </com.sonyericsson.rebuild.RebuildSettings>
 </properties>
 <scm class="hudson.scm.NullSCM"/>
EOF
   echo " <assignedNode>${instanceID}</assignedNode>" >> ${newCloudNodeCleanupJobConfigXml}
   cat >>${newCloudNodeCleanupJobConfigXml} <<EOF
 <canRoam>false</canRoam>
 <disabled>false</disabled>
 <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
 <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
 <triggers>
  <hudson.triggers.TimerTrigger>
   <spec>9 6 * * *</spec>
  </hudson.triggers.TimerTrigger>
 </triggers>
 <concurrentBuild>false</concurrentBuild>
 <builders>
  <hudson.tasks.Shell>
   <command>${LFS_CI_ROOT}/bin/jenkins-ci-execute-job.sh "${JOB_NAME}"</command>
  </hudson.tasks.Shell>
 </builders>
 <publishers/>
 <buildWrappers/>
</project>
EOF

    info config.xml for cloud node cleanup written.
    rawDebug ${newCloudNodeCleanupJobConfigXml}
}

## @fn      createNewJenkinsNodeAdminCleanupJob
#  @brief   create a new node for jenkins
#  @param   <none>
#  @return  <none>
createNewJenkinsNodeAdminCleanupJob() {
    local newCloudNodeCleanupJobConfigXml=$1
    mustExistFile ${newCloudNodeCleanupJobConfigXml}
    local instanceID=$2
    mustHaveValue "${instanceID}" "instanceID"
    local jenkinsCli=$(getConfig jenkinsCli)
    #mustExistFile ${jenkinsCli}

    info +++ TODO cat ${newCloudNodeCleanupJobConfigXml} '|' java -jar ${jenkinsCli}  -s http://maxi:1280 create-job Admin_-_cleanupBaselineShares_-_${instanceID}
    #cat ${newCloudNodeCleanupJobConfigXml} | java -jar ${jenkinsCli}  -s http://maxi:1280 create-job Admin_-_cleanupBaselineShares_-_${instanceID}
}

