#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/config.sh
source ${LFS_CI_ROOT}/lib/logging.sh

ftpGet() {
    local FTP_PATH=$1
    local FTP_FILE=$2
    local FTP_HOST=$(getConfig ftpHostAddress)
    local FTP_USER=$(getConfig ftpUserName)
    local FTP_PASSWD=$(getConfig ftpPassword)

    mustHaveValue "$FTP_PATH" "FTP_PATH"
    mustHaveValue "$FTP_FILE" "FTP_FILE"
    mustHaveValue "$FTP_HOST" "FTP_HOST"
    mustHaveValue "$FTP_USER" "FTP_USER"
    mustHaveValue "$FTP_PASSWD" "FTP_PASSWD"

ftp -n -v $FTP_HOST << EOT
user $FTP_USER $FTP_PASSWD
passive
prompt
cd $FTP_PATH
get $FTP_FILE
bye
EOT
}

