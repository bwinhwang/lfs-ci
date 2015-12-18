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
    mustExistsFile ${cloudUserRootDir}/${cloudEucarc}
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

    createNewCloudNodeAdminCleanupXMLConfig
    createNewJenkinsNodeAdminCleanupJob
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
    mustExistsFile ${newCloudNodeConfigXml}
    local jenkinsCli=$(getConfig JENKINS_CLI_JAR)
    info java -jar ${jenkinsCli}  -s http://maxi:1280  create-node < ${newCloudNodeConfigXml}
}

## @fn      createNewCloudNodeAdminCleanupXMLConfig
#  @brief   create a new config.xml for a new admin cleanup job of that node
#  @param   <none>
#  @return  <none>
createNewCloudNodeAdminCleanupXMLConfig() {
    info TODO createNewCloudNodeAdminCleanupXMLConfig ...
}

## @fn      createNewJenkinsNodeAdminCleanupJob
#  @brief   create a new node for jenkins
#  @param   <none>
#  @return  <none>
createNewJenkinsNodeAdminCleanupJob() {
    info TODO createNewJenkinsNodeAdminCleanupJob ...
}

