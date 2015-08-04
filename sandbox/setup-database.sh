#!/bin/bash

# Test database
DB_HOST="lfs-ci-metrics-database.dynamic.nsn-net.net"
DB_USER="test_lfspt"
DB_NAME="test_lfspt"
DB_PASS=""
TABLES_TO_COPY="branches events targets"

# Prod database
DB_PROD_HOST="lfs-ci-metrics-database.dynamic.nsn-net.net"
DB_PROD_USER="lfspt"
DB_PROD_NAME="lfspt"
DB_PROD_PASS=""

TMP="/tmp"
ITSME=$(basename $0)

while getopts ":s:t:p:q:" OPT; do
    case ${OPT} in
        s)
            DB_PROD_HOST=$OPTARG
        ;;
        t)
            DB_HOST=$OPTARG
        ;;
        p)
            DB_PROD_PASS=$OPTARG
        ;;
        q)
            DB_PASS=$OPTARG
        ;;
        u)
            DB_PROD_USER=$OPTARG
        ;;
        v)
            DB_USER=$OPTARG
        ;;
        *)
            echo "Use -h option to get help"
            exit 0
        ;;
    esac
done


usage() {
cat << EOF

    Usage: $ITSME [-s PROD_DB_HOST] [-t TEST_DB_HOST] [-p PROD_DB_PASS] [-q TEST_DB_PASS] [-u PROD_DB_USER] [-v TEST_DB_USER] 

    This script creates the ${DB_NAME} database on host ${DB_HOST} from scratch.
    The tables "${TABLES_TO_COPY}" are taken over from production database ${DB_PROD_NAME}
    running on ${DB_PROD_HOST}.

    Arguments (all of them are optional):
        -s Host name of production database. Defaults to ${DB_PROD_HOST}.
        -t Host name for test database. Defaults to ${DB_HOST}.
        -p Password of production database.
        -q Password for test database.
        -u User name of production database. Defaults to ${DB_PROD_USER}
        -v User name for test database. Defaults to ${DB_USER}

EOF
}

pre_checks() {
    if [[ -z ${DB_PASS} || -z ${DB_PROD_PASS} ]]; then
        echo "ERROR: Both mysql passwords are required"
        exit 1
    fi
    if [[ ${DB_NAME} == ${DB_PROD_NAME} ]]; then
        echo "ERROR: Name of test DB may not equal name of production DB."
        exit 1
    fi
}

create_db() {
    echo "DROP DATABASE ${DB_NAME}" | mysql -u ${DB_USER} --password=${DB_PASS}
    echo "CREATE DATABASE ${DB_NAME}" | mysql -u ${DB_USER} --password=${DB_PASS}
    cat ${LFS_CI_ROOT}/database/tables.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
    cat ${LFS_CI_ROOT}/database/views.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
    cat ${LFS_CI_ROOT}/database/procedures.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
    cat ${LFS_CI_ROOT}/database/ysmv2.tables.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
    cat ${LFS_CI_ROOT}/database/ysmv2.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
}

copy_db_tables() {
    for DB_TABLE in ${TABLES_TO_COPY}; do
        mysqldump --password=${DB_PROD_PASS} -h ${DB_PROD_HOST} -u ${DB_PROD_USER} ${DB_PROD_NAME} ${DB_TABLE} > ${TMP}/${DB_NAME}_${DB_TABLE}.sql
        cat ${TMP}/${DB_NAME}_${DB_TABLE}.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
        rm -f ${TMP}/${DB_NAME}_${DB_TABLE}.sql
    done
}

main() {

    if [[ "$1" == "--help" || "$1" == "-h" || -z $1 ]]; then
        usage
        exit 0
    fi

    pre_checks
    create_db
    copy_db_tables
}

main $*

