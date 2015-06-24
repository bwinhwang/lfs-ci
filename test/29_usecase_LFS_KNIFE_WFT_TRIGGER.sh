#!/bin/bash

. lib/common.sh
. lib/config.sh

initTempDirectory

export UT_MOCKED_COMMANDS=$(createTempFile)
export LFS_CI_ROOT=.

oneTimeSetUp() {
    export KNIFE_ID="92151"
    export KNIFE_BUILD_JOB="LFS_KNIFE_-_knife_-_Build"
    #export jobStatus="FAILURE"
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    curl() {
        if [[ $(echo $@ | grep "/info") ]]; then
            cat ${LFS_CI_ROOT}/test/data/knife.xml > ${WORKSPACE}/knife_${KNIFE_ID}.xml
        else
            mockedCommand "curl $@"
        fi
    }
    setBuildDescription() {
        true
    }
    ftpGet() {
        mockedCommand "ftpGet $@"
    }
    mustExistsFile() {
        mockedCommand "mustExistsFile $@"
    }
    mv() {
        mockedCommand "mv $@"
    }
    unzip() {
        mockedCommand "unzip $@"
    }
    java() {
        mockedCommand "java $@"
    }
    source() {
        if [[ $(echo $@ | grep "autoftp.sh") ]]; then
            true
        fi
    }
    executeJenkinsCli() {
        mockedCommand "executeJenkinsCli $@"
    }
    info()  {
        true
    }
    warning()  {
        true
    }
    error()  {
        true
    }
    . lib/uc_knife_build.sh
}

oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
}

tearDown() {
    true 
}

test_failed() {
    awk() {
        if [[ $(echo $@ | grep '{print $1}') ]]; then
            echo "#11"
        elif [[ $(echo $@ | grep '{print $8}') ]]; then
            echo "FAILURE"
        fi
    }
    . lib/uc_knife_build.sh
    usecase_LFS_KNIFE_WFT_TRIGGER
    local expected=$(createTempFile)
cat <<EOF > ${expected}
curl -k https://wft.inside.nsn.com/ext/knife/92151/started?access_key=hPPsISs8opgRADJsfG7wO7WlJ6uAIJSh7dfTQzE1
ftpGet ROTTA/eambrosc knife.zip
mustExistsFile knife.zip
mv knife.zip ${WORKSPACE}
unzip ${WORKSPACE}/knife.zip
java -jar ./lib/java/jenkins/jenkins-cli-1.532.3.jar -s https://maxi.emea.nsn-net.net:12443/ build LFS_KNIFE_-_knife_-_Build -p lfs.patch=${WORKSPACE}/lfs.patch -p KNIFE_LFS_BASELINE=PS_LFS_OS_2015_06_0150 -s
executeJenkinsCli set-build-result FAILURE
curl -k https://wft.inside.nsn.com/ext/knife/92151/failed?access_key=hPPsISs8opgRADJsfG7wO7WlJ6uAIJSh7dfTQzE1
EOF
    assertEquals "$(cat ${expected})" "$(cat ${UT_MOCKED_COMMANDS})"
    return
}

test_success() {
    awk() {
        if [[ $(echo $@ | grep '{print $1}') ]]; then
            echo "#11"
        elif [[ $(echo $@ | grep '{print $8}') ]]; then
            echo "SUCCESS"
        fi
    }
    . lib/uc_knife_build.sh
    usecase_LFS_KNIFE_WFT_TRIGGER
    local expected=$(createTempFile)
cat <<EOF > ${expected}
curl -k https://wft.inside.nsn.com/ext/knife/92151/started?access_key=hPPsISs8opgRADJsfG7wO7WlJ6uAIJSh7dfTQzE1
ftpGet ROTTA/eambrosc knife.zip
mustExistsFile knife.zip
mv knife.zip ${WORKSPACE}
unzip ${WORKSPACE}/knife.zip
java -jar ./lib/java/jenkins/jenkins-cli-1.532.3.jar -s https://maxi.emea.nsn-net.net:12443/ build LFS_KNIFE_-_knife_-_Build -p lfs.patch=${WORKSPACE}/lfs.patch -p KNIFE_LFS_BASELINE=PS_LFS_OS_2015_06_0150 -s
curl -k https://wft.inside.nsn.com/ext/knife/92151/succeeded?access_key=hPPsISs8opgRADJsfG7wO7WlJ6uAIJSh7dfTQzE1
executeJenkinsCli set-build-result SUCCESS
EOF
    assertEquals "$(cat ${expected})" "$(cat ${UT_MOCKED_COMMANDS})"
    return
}

source lib/shunit2

exit 0

