#!/bin/bash

function checkErrors {
    local comp_dir="${install_dir}/mysql/data"
    local mysql_log="${comp_dir}/mysqld.log"
    local errors=$(filterLog "${mysql_log}" "ERROR" 1)
    if [ ! -z "$errors" ]; then
        no_issues=false
        format "suggest" "Found recent error messages in the MySQL error log:$(format "wrap" "${errors}")Please check the following guide to troubleshoot MySQL issues:"
        format "link" "https://docs.bitnami.com/general/apps/wordpress/troubleshooting/debug-errors-mysql/"
    fi
}

function checkDatabase {
    local binlog_errors=false;
    local total=0
    local comp_dir="${install_dir}/mysql/data"
    local mysql_du_example="$(format "wrap" "$(du -m "${comp_dir}")")"
    local binlog="/opt/bitnami/mysql/data/binlog.index"
    if [[ -d ${comp_dir} ]]; then
        partition=$(df -P /opt/bitnami | cut -d' ' -f 1 | tail -1)
        total_space=$(df -m "${partition}" | tail -1 | awk '{print $2}')
        database_used_space=$(du -csm "${comp_dir}" | grep total | awk '{print $1}')
        total=$(( (database_used_space*100) / total_space ))
        if [[ $total -gt 50 ]]; then
            format "suggest" "The \"${comp_dir}\" folder is using ${total}%% of total disk space.${mysql_du_example}In most cases this is due to binary logging. Please check the following guide to disable it."
            format "link" "https://docs.bitnami.com/general/apps/wordpress/troubleshooting/disable-binary-logging-mysql/"
            no_issues=false
        fi
        binlog="${comp_dir}/binlog.index"
        while read -r line; do
            if ! sudo ls "/opt/bitnami/mysql/data/$line" > /dev/null 2>&1; then
                no_issues=false
                binlog_errors=true
            fi
        done 2> /dev/null < "$binlog"
    else
        no_issues=false
        format "suggest" "MySQL component not found."
    fi
    if $binlog_errors; then
        binlog_file=$(format "path" "$binlog")
        format "suggest" "The ${binlog_file} contains references to files that do not exist on disk. Please check the following guide:"
        format "link" "https://docs.bitnami.com/general/apps/wordpress/troubleshooting/disable-binary-logging-mysql/"
    fi
}

function checkPermissions {
    local comp_dir="${install_dir}/mysql/data"
    local wrong_permissions=false
    local perm_user=$(find "${comp_dir}" -user mysql ! -perm /u=w 2>/dev/null| wc -l)
    local perm_group=$(find "${comp_dir}" ! -user mysql -group mysql ! -perm /g=w 2>/dev/null | wc -l)
    local perm_others=$(find "${comp_dir}" ! -name mysql_upgrade_info ! -user mysql ! -group mysql ! -perm /o=w 2>/dev/null | wc -l)
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
        format "suggest" "Another installation of MySQL is running:$(format "wrap" "${system_mysql_example}") If Bitnami MySQL isn't starting this is the most likely cause. Please run the following command to stop it:$(format "code" "sudo systemctl disable mysql && sudo systemctl stop mysql")"
    fi
}

function validate {
    if [[ -d "${install_dir}/mysql/data" ]]; then
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

