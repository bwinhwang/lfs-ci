#!/bin/bash

## @file setup-database.sh
## @brief Create test database
## @details Creates the test database on $DB_HOST and applys 
##          the ${LFS_CI_ROOT_DB}/*.sql scripts. Also imports
##          some tables from production DB into new test DB.

ITSME=$(basename $0)
LFS_CI_ROOT_DB="${LFS_CI_ROOT}/database"
TMP="/tmp"

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

usage() {
cat << EOF

    Usage: $ITSME [-s PROD_DB_HOST] [-t TEST_DB_HOST] [-p PROD_DB_PASS] [-q TEST_DB_PASS] [-u PROD_DB_USER] [-v TEST_DB_USER] 

    This script creates the ${DB_NAME} database on host ${DB_HOST} from scratch.
    If -d is specified the name of the database is \${USER}_lfspt (${USER}_lfspt).
    The tables "${TABLES_TO_COPY}" are taken over from production database ${DB_PROD_NAME}
    running on ${DB_PROD_HOST}.

    Arguments:
        -p Password of production database.
        -q Password for test database.
        -s Host name of production database. Defaults to ${DB_PROD_HOST}.
        -t Host name for test database. Defaults to ${DB_HOST}.
        -u User name of production database. Defaults to ${DB_PROD_USER}
        -v User name for test database. Defaults to ${DB_USER} except -d is given.
        -d Use \${USER}_ (${USER}_) as prefix for the database name.

EOF
    exit 0
}

pre_checks() {
    if [[ -z ${LFS_CI_ROOT} ]]; then
        echo "ERROR: \$LFS_CI_ROOT must be set"
        exit 1
    fi
    if [[ -z ${DB_PASS} || -z ${DB_PROD_PASS} ]]; then
        echo "ERROR: Both mysql passwords are required"
        exit 1
    fi
    if [[ ${DB_NAME} == ${DB_PROD_NAME} ]]; then
        echo "ERROR: Name of test DB may not equal name of production DB."
        exit 1
    fi
}

## @fn create_db()
## @brief Create test database
## @details Creates the test database on $DB_HOST and applys 
##          the ${LFS_CI_ROOT_DB}/*.sql scripts.
create_db() {
    echo "Create database..."
    echo "    Drop database ${DB_NAME} on ${DB_HOST}"
    echo "DROP DATABASE ${DB_NAME}" | mysql -h ${DB_HOST} -u ${DB_USER} --password=${DB_PASS}
    echo "    Create database ${DB_NAME} on ${DB_HOST}"
    echo "CREATE DATABASE ${DB_NAME}" | mysql -h ${DB_HOST} -u ${DB_USER} --password=${DB_PASS}
    echo "    Create tables in database ${DB_NAME} on host ${DB_HOST}"
    cat ${LFS_CI_ROOT_DB}/tables.sql | mysql -h ${DB_HOST} -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
    cat ${LFS_CI_ROOT_DB}/ysmv2.tables.sql | mysql -h ${DB_HOST} -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
    echo "    Create views in database ${DB_NAME} on host ${DB_HOST}"
    cat ${LFS_CI_ROOT_DB}/views.sql | mysql -h ${DB_HOST} -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
    echo "    Create functions in database ${DB_NAME} on host ${DB_HOST}"
    cat ${LFS_CI_ROOT_DB}/procedures.sql | mysql -h ${DB_HOST} -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
    cat ${LFS_CI_ROOT_DB}/ysmv2.sql | mysql -h ${DB_HOST} -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
}

## @fn import_tables_from_prod()
## @brief Import database tables
## @details Import tables ${TABLES_TO_COPY} from production
#           database into test database
import_tables_from_prod() {
    echo "Export/import DB tables..."
    for DB_TABLE in ${TABLES_TO_COPY}; do
        echo "    Dump table ${DB_TABLE} of database ${DB_PROD_NAME} running on host ${DB_PROD_HOST}"
        mysqldump --password=${DB_PROD_PASS} -h ${DB_PROD_HOST} -u ${DB_PROD_USER} ${DB_PROD_NAME} ${DB_TABLE} > ${TMP}/${DB_NAME}_${DB_TABLE}.sql
        echo "    Import table ${DB_TABLE} into database ${DB_NAME} on host ${DB_HOST}"
        cat ${TMP}/${DB_NAME}_${DB_TABLE}.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
        rm -f ${TMP}/${DB_NAME}_${DB_TABLE}.sql
    done
}

get_args() {
    while getopts ":s:t:p:q:u:v:dh" OPT; do
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
            d)
                DB_NAME=${USER}_lfspt
            ;;
            h)
                usage
            ;;
            *)
                echo "Use -h option to get help"
                exit 0
            ;;
        esac
    done
}

main() {
    get_args $*
    pre_checks
    create_db
    import_tables_from_prod
}

main $*

