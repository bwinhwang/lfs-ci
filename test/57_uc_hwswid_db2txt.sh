#!/bin/bash

source test/common.sh
source lib/uc_hwswid_db2txt.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mkdir() {
        echo mkdir
    }
    cd() {
        echo cd
    }
    createHwSwIdTxtFile() {
        mockedCommand "createHwSwIdTxtFile $@"
    }
    hwSwIdToSubVersion() {
        mockedCommand "hwSwIdToSubVersion $@"
    }

    # create a temp file.cfg
    export UT_CFG_FILE=$(createTempFile)

    echo "LFS_CI_HWSWID_WORKDIR=/home/dems18x0/tmp/HwSwId" > ${UT_CFG_FILE}

    echo "MYSQL_db_name     < databaseName:hwswid_database > = test_flexibtshw               " >> ${UT_CFG_FILE}
    echo "MYSQL_db_username < databaseName:hwswid_database > = test_flexibtshw_ro            " >> ${UT_CFG_FILE}
    echo "MYSQL_db_password < databaseName:hwswid_database > =                               " >> ${UT_CFG_FILE}
    echo "MYSQL_db_hostname < databaseName:hwswid_database > = test_psweb.nsn-net.net        " >> ${UT_CFG_FILE}

    echo "LFS_CI_HWSWID_DB_TABLE < hw_platform:fsmr3 > = test_flexibtshw.v_fsmr3boards       " >> ${UT_CFG_FILE}
    echo "LFS_CI_HWSWID_DB_TABLE < hw_platform:fsmr4 > = test_flexibtshw.v_fsmr4boards       " >> ${UT_CFG_FILE}

    echo "LFS_CI_HWSWID_FIRMWARETYPE < hw_platform:fsmr3 > = uCCSSA CCSSAH uBMU CCSSA EC2 EC2G BMU0 BMU1 BMU2 BMU4 BMUM BMUK BMUP   " >> ${UT_CFG_FILE}
    echo "LFS_CI_HWSWID_FIRMWARETYPE < hw_platform:fsmr4 > = BMUQ BMUQ_X11 PCO2PEX PICASSOX02 PICASSOX03    " >> ${UT_CFG_FILE}

    echo "LFS_CI_HWSWID_BASEBANDFPGA < hw_platform:fsmr3 > = CPRIMON CPRIIF D4P " >> ${UT_CFG_FILE}

    echo "LFS_CI_HWSWID_URLS = XXX/os/trunk/fsmr3/src-fsmpsl/src/trailer.d XXX/os/trunk/fsmr3/src-fsmfirmware/src/trailer.d XXX/os/trunk/fsmr3/src-fsmbrm/src/trailer.d   " >> ${UT_CFG_FILE}

    export LFS_CI_CONFIG_FILE=${UT_CFG_FILE}


    # create HwSwId_uBMU.txt
    export HWSWID_TXT_FILE=$(createTempFile)
    echo "0x0020D001" > $HWSWID_TXT_FILE
    echo "0x0020D002" >> $HWSWID_TXT_FILE
    echo "0x0020D003" >> $HWSWID_TXT_FILE
    echo "0x0020D904" >> $HWSWID_TXT_FILE

    return
}

oneTimeTearDown() {
    return
}

setUp() {
    export LFS_CI_GLOBAL_PRODUCT_NAME=LFS

    return
}

tearDown() {
    return
}

test_setup() {
    echo +++ LFS_CI_CONFIG_FILE=${LFS_CI_CONFIG_FILE}
    cat ${LFS_CI_CONFIG_FILE}

    echo "+++ HWSWID_TXT_FILE:"
    cat ${HWSWID_TXT_FILE}

    echo ""
}

test_usecase_HWSWID_DB2TXT() {
    assertTrue "usecase_HWSWID_DB2TXT"

    return
}

test_createHwSwIdTxtFile() {
    assertTrue "createHwSwIdTxtFile"

    return
}

test_hwswidDataFromMysql_HwSwId_UBOOT_FSMR4_TXT() {
    hwswidTxtFile=$(createTempFile)
    query='1=1'
    currentMysqlTable="test_table"
    assertTrue "hwswidDataFromMysql ${hwswidTxtFile} ${query} ${currentMysqlTable}"

    cat ${hwswidTxtFile}

    return
}

test_hwswidRemoveMinorVersion() {
    assertTrue "hwswidRemoveMinorVersion ${HWSWID_TXT_FILE}"

    #cat ${HWSWID_TXT_FILE}

    return
}

test_hwSwIdToSubVersion() {
    assertTrue "hwSwIdToSubVersion"

    return
}


source lib/shunit2

exit 0
