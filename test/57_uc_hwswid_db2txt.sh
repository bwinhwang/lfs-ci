#!/bin/bash

source test/common.sh
source lib/uc_hwswid_db2txt.sh

oneTimeSetUp() {

    # create a temp file.cfg
    export UT_CFG_FILE=$(createTempFile)

    echo "LFS_CI_HWSWID_WORKDIR=/home/dems18x0/tmp/HwSwId" > ${UT_CFG_FILE}

    echo "MYSQL_db_name     < databaseName:hwswid_database > = flexibtshw               " >> ${UT_CFG_FILE}
    echo "MYSQL_db_username < databaseName:hwswid_database > = flexibtshw_ro            " >> ${UT_CFG_FILE}
    echo "MYSQL_db_password < databaseName:hwswid_database > =                          " >> ${UT_CFG_FILE}
    echo "MYSQL_db_hostname < databaseName:hwswid_database > = psweb.nsn-net.net        " >> ${UT_CFG_FILE}

    echo "LFS_CI_HWSWID_DB_TABLE < hw_platform:fsmr3 > = flexibtshw.v_fsmr3boards       " >> ${UT_CFG_FILE}
    echo "LFS_CI_HWSWID_DB_TABLE < hw_platform:fsmr4 > = flexibtshw.v_fsmr4boards       " >> ${UT_CFG_FILE}

    echo "LFS_CI_HWSWID_FIRMWARETYPE < hw_platform:fsmr3 > = uCCSSA CCSSAH uBMU CCSSA EC2 EC2G BMU0 BMU1 BMU2 BMU4 BMUM BMUK BMUP   " >> ${UT_CFG_FILE}
    echo "LFS_CI_HWSWID_FIRMWARETYPE < hw_platform:fsmr4 > = BMUQ BMUQ_X11 PCO2PEX PICASSOX02 PICASSOX03    " >> ${UT_CFG_FILE}

    echo "LFS_CI_HWSWID_BASEBANDFPGA < hw_platform:fsmr3 > = CPRIMON CPRIIF D4P " >> ${UT_CFG_FILE}

    echo "LFS_CI_HWSWID_URLS = ${BTS_SC_LFS_url}/os/trunk/fsmr3/src-fsmpsl/src/trailer.d ${BTS_SC_LFS_url}/os/trunk/fsmr3/src-fsmfirmware/src/trailer.d ${BTS_SC_LFS_url}/os/trunk/fsmr3/src-fsmbrm/src/trailer.d   " >> ${UT_CFG_FILE}

    export LFS_CI_CONFIG_FILE=${UT_CFG_FILE}

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
    cat ${LFS_CI_CONFIG_FILE}

    echo LFS_CI_CONFIG_FILE=${LFS_CI_CONFIG_FILE}
}

test_usecase_HWSWID_DB2TXT() {
    return
}

test_createHwSwIdTxtFile() {
    return
}

test_datafrommysql() {
    return
}

test_removeminor() {

    #assertTrue "Error in removeminor" "removeminor"

    return
}

test_HwSwIdToSubVersion() {
    return
}


source lib/shunit2

exit 0
