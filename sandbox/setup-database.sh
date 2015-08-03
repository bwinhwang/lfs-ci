DB_USER="debian-sys-maint"
DB_PASS=""
DB_NAME="test_lfspt"

while getopts ":n:p:u:" OPT; do
    case ${OPT} in
        u)
            DB_USER=$OPTARG
        ;;
        p)
            DB_PASS=$OPTARG
        ;;
        n)
            DB_NAME=$OPTARG
        ;;
    esac
done

if [[ -z ${DB_PASS} ]]; then
    echo "ERROR: mysql password is required"
    exit 1
fi

echo "DROP DATABASE test_lfspt" | mysql -u ${DB_USER} --password=${DB_PASS}
echo "CREATE DATABASE test_lfspt" | mysql -u ${DB_USER} --password=${DB_PASS}
cat ${LFS_CI_ROOT}/database/tables.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
cat ${LFS_CI_ROOT}/database/views.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}
cat ${LFS_CI_ROOT}/database/procedures.sql | mysql -u ${DB_USER} --password=${DB_PASS} ${DB_NAME}

