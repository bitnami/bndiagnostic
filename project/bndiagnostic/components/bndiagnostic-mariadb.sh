#!/bin/bash

function checkErrors {
    local comp_dir="${install_dir}/mariadb"
    local mariadb_log="${comp_dir}/logs/mysqld.log"
    local errors=$(filterLog "${mariadb_log}" "Error" 1)
    if [ ! -z "$errors" ]; then
        no_issues=false
        format "suggest" "Found recent error messages in the MariaDB error log:$(format "wrap" "${errors}")Please check the following guide to troubleshoot MariaDB issues:"
        format "link" "https://docs.bitnami.com/aws/apps/wordpress/troubleshooting/debug-errors-mariadb/"
    fi
}

function checkPermissions {
    local comp_dir="${install_dir}/mariadb/data/"
    local wrong_permissions=false
    local permls_user=$(find -L "${comp_dir}" -type f -user mysql ! -perm /u=w 2>/dev/null| wc -l)
    local perm_group=$(find -L "${comp_dir}"  -type f -group mysql ! -perm /g=w 2>/dev/null | wc -l)
    local perm_others=$(find -L "${comp_dir}" ! -user mysql -perm /o=w,g=w -or ! -group mysql -perm /o=w,g=w 2>/dev/null | wc -l)
    local count=$(( perm_user + perm_group + perm_others ))
    if [[ "$count" -gt 0 ]]; then
        no_issues=false
        wrong_permissions=true
    fi
    if $wrong_permissions; then
        format "suggest" "Some files don't have the expected permissions. Please check the following guide:"
        format "link" "https://docs.bitnami.com/general/how-to/troubleshoot-permission-issues/"
    fi
}

function checkSystemMySQL {
    local system_mysql_is_running=$(ps aux | grep mysql | grep -v bitnami | grep -v grep | wc -l)
    local system_mysql_example=$(ps aux | grep mysql  | head -2)
    if [ $system_mysql_is_running -gt 0 ]; then
        no_issues=false
        format "suggest" "Another installation of MariaDB is running:$(format "wrap" "${system_mysql_example}")If Bitnami MariaDB isn't starting this is the most likely cause. Please run the following command to stop it:$(format "code" "sudo systemctl disable mariadb && sudo systemctl stop mariadb")"
    fi
}

function checkDatabase {
    local total=0;
    local comp_dir="${install_dir}/mariadb/data"
    local mariadb_du_example=$(format "wrap" "$(du -m "${comp_dir}")")
    if [[ -d ${comp_dir} ]]; then
        partition=$(df -P /opt/bitnami | cut -d' ' -f 1 | tail -1)
        total_used_space=$(df -m "${partition}" | tail -1 | awk '{print $3}')
        database_used_space=$(du -csm "${comp_dir}" | grep total | awk '{print $1}')
        total=$(( (database_used_space*100) / total_used_space ))
        if [[ $total -gt 90 ]]; then
            format "suggest" "The \"${comp_dir}\" folder is using ${total}%% of disk space. $(formatMessage wrap "${mariadb_du_example}") In most cases this is due to binary logging. Please check the following guide to disable it."
            format "link" "https://docs.bitnami.com/general/apps/wordpress/troubleshooting/disable-binary-logging-mysql/"
            no_issues=false
        fi
    else
        no_issues=false
        format "suggest" "MySQL component not found."
    fi
}

function validate {
    if [[ -d "${install_dir}/mariadb/data" ]]; then
        echo "1";
    else
        echo "0";
    fi
}

function run {
    no_issues=true
    format "section" "${component^}"
    checkErrors
    checkDatabase
    checkSystemMySQL
    checkPermissions
    addStatus "${component^}" "$no_issues"
    if $no_issues; then
        format "clear" "${no_issues}"
    fi
}